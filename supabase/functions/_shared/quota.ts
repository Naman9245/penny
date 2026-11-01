// The daily limits, kept by the take_ai_call and refund_ai_call functions in
// the database. Only the functions' secret key can run them.

/** A Supabase client's rpc, as the functions use it. */
type Rpc = (
  fn: string,
  args: Record<string, unknown>,
) => PromiseLike<{ data: unknown; error: { message: string } | null }>;

/** Counting for one [kind] of call, with its own limits. */
export function quota(
  rpc: Rpc,
  kind: "report" | "chat",
  userLimit: number,
  totalLimit: number,
) {
  return {
    async takeCall(userId: string): Promise<number> {
      const { data, error } = await rpc("take_ai_call", {
        p_user_id: userId,
        p_kind: kind,
        p_user_limit: userLimit,
        p_total_limit: totalLimit,
      });
      if (error) throw new Error(error.message);
      return data as number;
    },
    async refundCall(userId: string): Promise<void> {
      const { error } = await rpc("refund_ai_call", {
        p_user_id: userId,
        p_kind: kind,
      });
      if (error) throw new Error(error.message);
    },
  };
}
