import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.57.4";

const jsonHeaders = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };

export function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

export function adminClient(): SupabaseClient | null {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const secret = Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
  if (!url || !secret) return null;
  return createClient(url, secret, { auth: { persistSession: false } });
}

export async function readBody(request: Request, maxBytes: number): Promise<string | null> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (declared > maxBytes) return null;
  const buffer = new Uint8Array(await request.arrayBuffer());
  if (buffer.byteLength > maxBytes) return null;
  return new TextDecoder().decode(buffer);
}

/** Constant-time comparison of two byte arrays of possibly different length. */
export function timingSafeEqual(left: Uint8Array, right: Uint8Array): boolean {
  let difference = left.length ^ right.length;
  const size = Math.max(left.length, right.length, 1);
  for (let index = 0; index < size; index += 1) {
    difference |= (left[index % (left.length || 1)] ?? 0) ^ (right[index % (right.length || 1)] ?? 0);
  }
  return difference === 0;
}

export function base64ToBytes(value: string): Uint8Array<ArrayBuffer> {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export function isoOrNull(milliseconds: unknown): string | null {
  const value = Number(milliseconds);
  return Number.isFinite(value) && value > 0 ? new Date(value).toISOString() : null;
}
