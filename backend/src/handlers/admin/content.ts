// 管理端通用内容表 CRUD：一套 handler 顶 11 张表，靠白名单挡住不该碰的集合。
import { getDb } from '../../db';
import { bad, ok, Req } from '../../http';
import { audit } from './audit';

/** 内容/配置集合白名单：物理删，无归属校验（管理端全权维护） */
export const CONTENT_COLS = new Set([
  'preset_wishes',
  'preset_steps',
  'poster_task',
  'poster_wish',
  'poster_done',
  'hero_images',
  'achv_defs',
  'spots',
  'blockwords',
  'announcements',
]);

/** 三张用户数据同步表：管理端数据表页也要能查看/改，但删除必须走软删——
 * 物理删会让用户端下次 /sync/pull 拉不到这条记录，既不会同步删除也可能造成脏数据。 */
const SYNC_COLS = new Set(['wishes', 'tasks', 'letters']);

function colAllowed(col: string): boolean {
  return CONTENT_COLS.has(col) || SYNC_COLS.has(col);
}

/** query 里 f_字段=值 转成等值过滤；'true'/'false' 转布尔，其余原样当字符串 */
function parseFilters(query: Record<string, string>): Record<string, unknown> {
  const where: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(query ?? {})) {
    if (!k.startsWith('f_') || k.length <= 2) continue;
    where[k.slice(2)] = v === 'true' ? true : v === 'false' ? false : v;
  }
  return where;
}

/** GET /admin/content/:col —— 分页 + f_ 等值过滤。
 * 集合还没建过（hero_images 这类种子没灌的空表）时建好并按空表返回，别 500。 */
export async function list(req: Req, col: string) {
  if (!colAllowed(col)) return bad('unknown_collection');
  const q = req.query ?? {};
  const skip = Math.max(0, Number(q.skip) || 0);
  const limit = Math.min(100, Math.max(1, Number(q.limit) || 20));
  try {
    const { items, total } = await getDb().listDocs(col, { skip, limit, where: parseFilters(q) });
    return ok({ items, total });
  } catch {
    await getDb().ensureCollection(col);
    return ok({ items: [], total: 0 });
  }
}

/** POST /admin/content/:col，body: { id?, doc } —— 无 id 新建，有 id 更新；
 * 指定的 id 还不存在时按该 id 建新文档（upsertDoc 的 update 分支建不了文档，
 * announcements 里 sys_min_version 这种固定 id 的配置文档第一次写就靠这个）。 */
export async function upsert(req: Req, col: string) {
  if (!colAllowed(col)) return bad('unknown_collection');
  const b = req.body ?? {};
  const doc = b.doc && typeof b.doc === 'object' ? b.doc : {};
  const id = typeof b.id === 'string' && b.id ? b.id : undefined;
  const db = getDb();
  const payload = { ...doc, updatedAt: Date.now() };
  let newId: string;
  if (id) {
    const { items } = await db.listDocs(col, { where: { _id: id }, limit: 1 });
    if (items.length === 0) {
      await db.createDoc(col, id, payload);
    } else {
      await db.upsertDoc(col, id, payload);
    }
    newId = id;
  } else {
    newId = await db.upsertDoc(col, undefined, payload);
  }
  await audit(id ? 'update' : 'create', col, newId);
  return ok({ id: newId });
}

/** POST /admin/content/:col/delete，body: { id } —— 内容表物理删，同步表软删 */
export async function remove(req: Req, col: string) {
  if (!colAllowed(col)) return bad('unknown_collection');
  const id = typeof req.body?.id === 'string' ? req.body.id : '';
  if (!id) return bad('id_required');
  if (SYNC_COLS.has(col)) {
    await getDb().upsertDoc(col, id, { deleted: true, updatedAt: Date.now() });
  } else {
    await getDb().deleteDoc(col, id);
  }
  await audit('delete', col, id);
  return ok({ id });
}
