// Small helpers every function uses.

/** A JSON error reply, `{ error, ...extra }`. */
export function fail(
  status: number,
  error: string,
  extra: Record<string, unknown> = {},
): Response {
  return Response.json({ error, ...extra }, { status });
}

/** The body as text, or null when it is over [maxBytes]. */
export async function readBody(
  req: Request,
  maxBytes: number,
): Promise<string | null> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > maxBytes) return null;
  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.byteLength > maxBytes) return null;
  return new TextDecoder().decode(bytes);
}

export function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** A positive whole number from the environment, or [fallback]. */
export function limitFrom(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name));
  return Number.isInteger(value) && value > 0 ? value : fallback;
}
