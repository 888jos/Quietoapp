import postgres from "postgres";
import { readManifest, readNDJSON, requireEnv, sha256File, stableJSON } from "./lib.mjs";

const directory = process.argv[2];
if (!directory) throw new Error("Usage: npm run import -- /chemin/du/snapshot");
const manifest = await readManifest(directory);
for (const [name, expected] of Object.entries(manifest.files)) {
  const actual = await sha256File(`${directory}/${name}`);
  if (actual !== expected.sha256) throw new Error(`Checksum invalide: ${name}`);
}

const sql = postgres(requireEnv("SUPABASE_DB_URL"), { max: 1, ssl: "require", prepare: false });
const [run] = await sql`
  insert into migration.runs (source, phase, status, source_project, manifest_sha256, record_counts)
  values ('firebase_revenuecat', 'import', 'running', ${manifest.source.firebaseProject}, ${await sha256File(`${directory}/manifest.json`)}, ${sql.json(Object.fromEntries(Object.entries(manifest.files).map(([key, value]) => [key, value.count])))})
  returning id
`;

try {
  for await (const user of readNDJSON(`${directory}/firebase-auth-users.ndjson`)) {
    await sql.begin(async (transaction) => {
      await transaction`
        insert into migration.firebase_auth_users
          (firebase_uid, email, is_anonymous, disabled, providers, custom_claims, raw_user)
        values (${user.uid}, ${user.email}, ${user.isAnonymous}, ${user.disabled}, ${transaction.json(user.providers)}, ${transaction.json(user.customClaims)}, ${transaction.json(user)})
        on conflict (firebase_uid) do update set
          email = excluded.email, is_anonymous = excluded.is_anonymous, disabled = excluded.disabled,
          providers = excluded.providers, custom_claims = excluded.custom_claims, raw_user = excluded.raw_user,
          exported_at = now()
      `;
      await transaction`
        insert into public.profiles (user_id, firebase_uid, first_name, is_anonymous)
        values (${user.uid}, ${user.uid}, ${user.displayName}, ${user.isAnonymous})
        on conflict (user_id) do update set firebase_uid = excluded.firebase_uid,
          first_name = coalesce(public.profiles.first_name, excluded.first_name),
          is_anonymous = excluded.is_anonymous
      `;
    });
  }

  for await (const document of readNDJSON(`${directory}/firestore-documents.ndjson`)) {
    await sql`
      insert into migration.firebase_documents (collection_path, document_id, raw_data, create_time, update_time)
      values (${document.collectionPath}, ${document.documentId}, ${sql.json(document.data)}, ${document.createTime}, ${document.updateTime})
      on conflict (collection_path, document_id) do update set raw_data = excluded.raw_data,
        create_time = excluded.create_time, update_time = excluded.update_time, exported_at = now()
    `;
  }

  for await (const record of readNDJSON(`${directory}/revenuecat-customers.ndjson`)) {
    const subscriber = record.customer?.subscriber ?? {};
    const premium = subscriber.entitlements?.premium ?? null;
    const expiresAt = premium?.expires_date ?? null;
    const active = Boolean(premium) && (!expiresAt || Date.parse(expiresAt) > Date.now());
    await sql.begin(async (transaction) => {
      await transaction`
        insert into migration.revenuecat_customers (app_user_id, original_app_user_id, aliases, raw_customer, fetched_at)
        values (${record.appUserId}, ${subscriber.original_app_user_id ?? record.appUserId}, ${subscriber.original_app_user_id ? [subscriber.original_app_user_id] : []}, ${transaction.json(record.customer)}, ${record.fetchedAt})
        on conflict (app_user_id) do update set original_app_user_id = excluded.original_app_user_id,
          aliases = excluded.aliases, raw_customer = excluded.raw_customer, fetched_at = excluded.fetched_at
      `;
      await transaction`
        insert into public.subscription_accounts
          (user_id, revenuecat_app_user_id, original_app_user_id, status, product_id, store, expires_at, will_renew, source, source_updated_at, raw_customer_info)
        values (${record.appUserId}, ${record.appUserId}, ${subscriber.original_app_user_id ?? record.appUserId},
          ${active ? (premium?.period_type === "trial" ? "trial" : "active") : "inactive"}, ${premium?.product_identifier ?? null},
          ${premium?.store ?? null}, ${expiresAt}, ${premium?.unsubscribe_detected_at == null}, 'migration', ${record.fetchedAt}, ${transaction.json(record.customer)})
        on conflict (user_id) do update set
          revenuecat_app_user_id = excluded.revenuecat_app_user_id,
          original_app_user_id = excluded.original_app_user_id,
          status = excluded.status, product_id = excluded.product_id, store = excluded.store,
          expires_at = excluded.expires_at, will_renew = excluded.will_renew,
          source = excluded.source, source_updated_at = excluded.source_updated_at,
          raw_customer_info = excluded.raw_customer_info
      `;
    });
  }

  for (const [name, value] of Object.entries(manifest.files)) {
    await sql`insert into migration.checksums (run_id, source_object, row_count, sha256)
      values (${run.id}, ${name}, ${value.count}, ${value.sha256})`;
  }
  await sql`update migration.runs set status = 'succeeded', finished_at = now() where id = ${run.id}`;
  console.log(JSON.stringify({ ok: true, runId: run.id, manifest: stableJSON(manifest) }));
} catch (error) {
  await sql`update migration.runs set status = 'failed', notes = ${String(error)}, finished_at = now() where id = ${run.id}`;
  throw error;
} finally {
  await sql.end();
}

