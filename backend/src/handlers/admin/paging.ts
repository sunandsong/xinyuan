/** 管理端列表分页：limit 默认 30，最大 100 */
export function pageLimit(q: Record<string, string | undefined> | undefined, fallback = 30): number {
  const n = Number(q?.limit);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(100, Math.max(1, Math.floor(n)));
}
