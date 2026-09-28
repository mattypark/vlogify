/// ISO-8601 without milliseconds. Swift's `.iso8601` date strategy rejects fractional seconds,
/// so everything the phone decodes goes through this.
export function iso(date: Date = new Date()): string {
  return date.toISOString().replace(/\.\d{3}Z$/, "Z");
}

export function now(): string {
  return iso();
}

/// 128-bit random id, base64url (22 chars). Safe in URL paths and R2 keys.
export function randomId(bytes = 16): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return base64url(buf);
}

export function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/// Strict base64url (no padding, no whitespace) to bytes; null for anything else.
export function fromBase64url(value: string): Uint8Array | null {
  if (!/^[A-Za-z0-9_-]*$/.test(value) || value.length % 4 === 1) return null;
  const padded = value.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((value.length + 3) % 4);
  try {
    const binary = atob(padded);
    return Uint8Array.from(binary, (c) => c.charCodeAt(0));
  } catch {
    return null;
  }
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

function hex(buffer: ArrayBuffer): string {
  return [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function sha256Hex(input: string): Promise<string> {
  return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input)));
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"],
  );
}

export async function hmacHex(secret: string, input: string): Promise<string> {
  return hex(await crypto.subtle.sign("HMAC", await hmacKey(secret), new TextEncoder().encode(input)));
}

/// Constant-time check of a hex HMAC (subtle.verify compares in constant time).
export async function hmacVerify(secret: string, input: string, signatureHex: string): Promise<boolean> {
  if (!/^[0-9a-f]{64}$/.test(signatureHex)) return false;
  const signature = new Uint8Array(signatureHex.match(/../g)!.map((pair) => parseInt(pair, 16)));
  return crypto.subtle.verify("HMAC", await hmacKey(secret), signature, new TextEncoder().encode(input));
}

async function aesKey(base64Key: string): Promise<CryptoKey> {
  return crypto.subtle.importKey("raw", fromBase64(base64Key), "AES-GCM", false, ["encrypt", "decrypt"]);
}

/// AES-GCM seal -> "iv.ciphertext" (both base64url).
export async function sealString(base64Key: string, plaintext: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const sealed = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv }, await aesKey(base64Key), new TextEncoder().encode(plaintext),
  );
  return `${base64url(iv)}.${base64url(new Uint8Array(sealed))}`;
}

export async function openString(base64Key: string, sealed: string): Promise<string> {
  const [ivPart, dataPart] = sealed.split(".");
  const iv = ivPart ? fromBase64url(ivPart) : null;
  const data = dataPart ? fromBase64url(dataPart) : null;
  if (!iv || !data) throw new Error("malformed sealed value");
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, await aesKey(base64Key), data);
  return new TextDecoder().decode(plain);
}

/// Grapheme-aware prefix, so a name cut at the cap never splits an emoji. Swift counts
/// `Character`s, which are grapheme clusters; this counts the same thing.
export function prefixGraphemes(value: string, max: number): string {
  const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });
  let out = "";
  let count = 0;
  for (const { segment } of segmenter.segment(value)) {
    if (count === max) break;
    out += segment;
    count += 1;
  }
  return out;
}
