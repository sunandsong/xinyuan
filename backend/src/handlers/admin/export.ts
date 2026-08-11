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
async function dumpCollection(col: string): Promise<{ items: any[]; truncated: boolean }> {
  const items: any[] = [];
  let skip = 0;
  try {
    for (;;) {
      const { items: page } = await getDb().listDocs(col, { skip, limit: PAGE });
      items.push(...page);
      if (page.length < PAGE || items.length >= MAX_PER_COLLECTION) break;
      skip += PAGE;
    }
  } catch {
    return { items: [], truncated: false };
  }
  return items.length > MAX_PER_COLLECTION
    ? { items: items.slice(0, MAX_PER_COLLECTION), truncated: true }
    : { items, truncated: false };
}

const ALL_COLS = [
  COL.users,
  COL.wishes,
  COL.tasks,
  COL.letters,
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
  for (const [col, { items, truncated: t }] of entries) {
    collections[col] = col === COL.users ? items.map(({ passwordHash, ...rest }) => rest) : items;
    if (t) truncated.push(col);
  }

  return ok({ exportedAt: Date.now(), collections, truncated });
}
