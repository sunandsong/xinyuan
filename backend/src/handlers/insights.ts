import { getDb } from '../db';
import { bad, ok, Req } from '../http';

/** 内容榜跟用户榜（leaderboard.ts）分开算，就取一样的前 10 名 */
const LIMIT = 10;
/** 穿透列表（谁完成过/谁打卡过）多给一点，反正只给昵称头像 */
const DRILL_LIMIT = 50;

/** GET /api/insights/wishes —— 哪个心愿被最多人完成过（跨全部用户统计标题，不看是谁完成的） */
export async function wishInsights(_req: Req) {
  const db = getDb();
  const top = await db.topWishTitles(LIMIT);
  return ok({
    top: top.map((w, i) => ({ rank: i + 1, title: w.title, count: w.count })),
  });
}

/** GET /api/insights/places —— 哪个景点被最多人打卡过 */
export async function placeInsights(_req: Req) {
  const db = getDb();
  const top = await db.topPlaces(LIMIT);
  return ok({
    top: top.map((p, i) => ({ rank: i + 1, place: p.place, count: p.count })),
  });
}

/** GET /api/insights/wishes/stats?title=xxx —— 这个心愿多少人也想做/已实现（不含自己） */
export async function wishStats(req: Req, uid: string) {
  const title = String(req.query.title ?? '').trim();
  if (!title) return bad('title_required');
  const db = getDb();
  return ok(await db.wishTitleStats(title, uid));
}

/** GET /api/insights/wishes/users?title=xxx —— 穿透：谁完成过这个心愿 */
export async function wishCompleters(req: Req) {
  const title = String(req.query.title ?? '').trim();
  if (!title) return bad('title_required');
  const db = getDb();
  const users = await db.usersWhoCompletedWish(title, DRILL_LIMIT);
  return ok({ users });
}

/** GET /api/insights/places/users?place=xxx —— 穿透：谁打卡过这个景点 */
export async function placeVisitors(req: Req) {
  const place = String(req.query.place ?? '').trim();
  if (!place) return bad('place_required');
  const db = getDb();
  const users = await db.usersWhoCheckedIn(place, DRILL_LIMIT);
  return ok({ users });
}
