import { readFile, readdir } from "node:fs/promises";
import { parse } from "pgsql-parser";

const directory = new URL("../../supabase/migrations/", import.meta.url);
const files = (await readdir(directory)).filter((file) => file.endsWith(".sql")).sort();
for (const file of files) {
  await parse(await readFile(new URL(file, directory), "utf8"));
  console.log(`SQL valide: ${file}`);
}
