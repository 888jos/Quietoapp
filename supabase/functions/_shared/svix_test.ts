import { assertEquals } from "jsr:@std/assert@1";
import { verifySvixSignature } from "./svix.ts";

// Reference vector from the Svix documentation.
const secret = "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw";
const body = '{"test": 2432232314}';
const headers = (signature: string, timestamp = "1614265330") =>
  new Headers({ "svix-id": "msg_p5jXN8AQM9LWM0D4loKWxJek", "svix-timestamp": timestamp, "svix-signature": signature });

Deno.test("accepts the Svix reference signature", async () => {
  assertEquals(await verifySvixSignature(secret, headers("v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE="), body, 1614265330), true);
});

Deno.test("accepts when one of several signatures matches", async () => {
  assertEquals(await verifySvixSignature(secret, headers("v1,AAAA v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE="), body, 1614265330), true);
});

Deno.test("rejects a modified body, a wrong secret and an old timestamp", async () => {
  const good = "v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE=";
  assertEquals(await verifySvixSignature(secret, headers(good), '{"test": 1}', 1614265330), false);
  assertEquals(await verifySvixSignature("whsec_AAAAAAAAAAAAAAAAAAAAAAAAAAAA", headers(good), body, 1614265330), false);
  assertEquals(await verifySvixSignature(secret, headers(good), body, 1614265330 + 600), false);
  assertEquals(await verifySvixSignature(secret, headers("v2,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE="), body, 1614265330), false);
});
