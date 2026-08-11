// 管理端操作审计：占位实现，先保证写操作有落地日志。
// Task 8 会补充查询接口、更多字段（操作者、before/after diff 等），
// 这里只管把动作记下来——审计失败绝不能拖垮主业务写操作，全部吞掉。
import { getDb } from '../../db';

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
