// 管理端全库导出：一次性拉全部集合数据，供管理员本地留档/迁移。只读，不接 audit。
import { COL } from '../../config';
import { getDb } from '../../db';
import { ok, Req } from '../../http';
import { CONTENT_COLS } from './content';

/** 单集合最多拉这么多条，超出标记 truncated——云函数响应体上限约 6MB，
 * 简单版先按条数硬顶，不做真实字节量估算。 */
const MAX_PER_COLLECTION = 5000;
/** 单次查询上限（跟 db.ts 的 QUERY_LIMIT 对齐），翻页拉到 MAX_PER_COLLECTION 或拉空为止 */
const PAGE = 1000;

/** 单集合翻页拉全；集合在这个环境还没建过（ResourceNotFound）时按空集合处理——
 * 跟 config.ts 的 listActive 是同一个道理：导出要尽量给出结果，不能因为一张表还没
 * 建过就让整个导出 500。 */
export async function dumpCollection(col: string): Promise<{ items: any[]; truncated: boolean; errored?: boolean }> {
  const items: any[] = [];
  let skip = 0;
  let truncated = false;
  try {
    for (;;) {
      const { items: page } = await getDb().listDocs(col, { skip, limit: PAGE });
      items.push(...page);
      // MAX_PER_COLLECTION 是 PAGE 的整数倍，命中上限时 items.length 精确等于它——
      // 用 items.length > MAX_PER_COLLECTION 判断截断永远是 false，是死代码。
      if (items.length >= MAX_PER_COLLECTION) {
        // 最后一页没拉满，说明这就是全部数据，没有更多，肯定没截断。
        // 拉满了则不能单凭这页断定——总数恰好等于上限时最后一页也会是满的，
        // 所以额外探一页极小的（limit:1）确认后面是否真有数据，避免恰好等于
        // 上限的集合被误报成 truncated（这只在命中上限那一次多发一次请求）。
        truncated = page.length === PAGE && (await getDb().listDocs(col, { skip: skip + PAGE, limit: 1 })).items.length > 0;
        break;
      }
      if (page.length < PAGE) break;
      skip += PAGE;
    }
  } catch {
    // 查询异常（含集合还没建过）：以前静默当空集合，跟「这张表本来就没数据」没法区分，
    // 加个 errored 标记，让调用方知道这条不是真的空，是查失败了。
    return { items: [], truncated: false, errored: true };
  }
  return { items: items.slice(0, MAX_PER_COLLECTION), truncated };
}

const ALL_COLS = [
  COL.users,
  COL.wishes,
  COL.tasks,
  COL.letters,
  COL.shares,
  COL.feedback,
  COL.logins,
  COL.events,
  'admin_audit',
  ...CONTENT_COLS,
];

/** GET /admin/export —— 全库 JSON 导出，users 剥 passwordHash */
export async function exportAll(_req: Req) {
  const entries = await Promise.all(ALL_COLS.map(async (col) => [col, await dumpCollection(col)] as const));

  const collections: Record<string, any[]> = {};
  const truncated: string[] = [];
  const errored: string[] = [];
  for (const [col, { items, truncated: t, errored: e }] of entries) {
    collections[col] = col === COL.users ? items.map(({ passwordHash, ...rest }) => rest) : items;
    if (t) truncated.push(col);
    if (e) errored.push(col);
  }

  return ok({ exportedAt: Date.now(), collections, truncated, errored });
}
