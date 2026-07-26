import { getDb } from '../db';
import { bad, notFound, ok, Req } from '../http';
import { Share } from '../types';

const ALPHABET = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
function genCode(len = 6): string {
  let s = '';
  for (let i = 0; i < len; i++) s += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  return s;
}

/** POST /api/share —— 为某心愿生成分享（存只读快照 + 短码），返回短链信息 */
export async function createShare(req: Req, uid: string) {
  const b = req.body ?? {};
  if (!b.wishId || typeof b.title !== 'string') return bad('wishId_and_title_required');

  const db = getDb();
  // 取一个未占用的短码
  let code = genCode();
  for (let i = 0; i < 5 && (await db.getShareByCode(code)); i++) code = genCode();

  const now = Date.now();
  const share: Share = {
    _id: `s_${code}`,
    code,
    uid,
    wishId: String(b.wishId),
    snapshot: {
      title: String(b.title).slice(0, 60),
      quote: typeof b.quote === 'string' ? b.quote.slice(0, 120) : null,
      color: typeof b.color === 'string' ? b.color : 'A8B8F8',
    },
    views: 0,
    createdAt: now,
    expireAt: null,
  };
  await db.createShare(share);
  // 后续接 EdgeOne 后，短链形如 https://<域名>/s/<code>
  return ok({ code, path: `/s/${code}` });
}

/** GET /api/share/:code —— 公开只读，返回分享快照并计数（分享页数据源） */
export async function getShare(_req: Req, code: string) {
  const db = getDb();
  const share = await db.getShareByCode(code);
  if (!share) return notFound();
  await db.bumpShareViews(code);
  return ok({ snapshot: share.snapshot, views: share.views + 1, createdAt: share.createdAt });
}
