// 管理端操作审计：写操作落地日志 + Task 8 补的查询接口。
// 审计失败绝不能拖垮主业务写操作，写入全部吞掉。
import { getDb } from '../../db';
import { ok, Req } from '../../http';
import { pageLimit } from './paging';

export async function audit(action: string, col: string, id: string, detail?: unknown): Promise<void> {
  try {
    await getDb().upsertDoc('admin_audit', undefined, {
      action,
      target: `${col}:${id}`,
      detail: detail ?? null,
      at: Date.now(),
    });
  } catch {
    // 审计表写不进去不该影响管理端本次操作的成败
  }
}

/** GET /admin/audit?skip=&limit= —— 审计日志，按时间倒序分页 */
export async function list(req: Req) {
  const q = req.query ?? {};
  const skip = Math.max(0, Number(q.skip) || 0);
  const { items, total } = await getDb().listDocs('admin_audit', {
    skip,
    limit: pageLimit(q),
    orderBy: 'at',
    orderDir: 'desc',
  });
  return ok({ items, total });
}
