import { getDb } from '../db';
import { notFound, ok, Req } from '../http';

/** 排行榜四个榜单对应的计数字段 */
const FIELDS = ['doneCount', 'taskCount', 'achvCount', 'placeCount'] as const;

/** 按生日算周岁，跟前端 me_tab.dart 的 _ageOf 逻辑一致。
 * 只往外吐算好的年龄，不吐生日本身——生日具体哪天比年龄更私密。 */
function ageFromBirthday(birthday: string): number | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(birthday);
  if (!m) return null;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const now = new Date();
  let age = now.getFullYear() - y;
  if (now.getMonth() + 1 < mo || (now.getMonth() + 1 === mo && now.getDate() < d)) {
    age--;
  }
  return age < 0 ? 0 : age;
}

/** GET /api/users/:id —— 排行榜点进详情用，只给公开信息：
 * 昵称/头像/性别/年龄 + 四项统计与名次 + 已解锁勋章 slug 列表。
 * 不返回账号名、生日具体日期、心愿/任务/打卡等具体内容。 */
export async function getPublicProfile(_req: Req, targetUid: string) {
  const db = getDb();
  const profile = await db.getProfile(targetUid);
  if (!profile || profile.deleted) return notFound();

  const counts: Record<string, number> = {};
  const ranks: Record<string, number | null> = {};
  await Promise.all(
    FIELDS.map(async (f) => {
      const v = (profile as any)[f] ?? 0;
      counts[f] = v;
      ranks[f] = v > 0 ? (await db.countAbove(f, v)) + 1 : null;
    }),
  );

  return ok({
    nickname: profile.nickname || '匿名',
    avatarUrl: profile.avatarUrl ?? null,
    gender: profile.gender ?? null,
    age: profile.birthday ? ageFromBirthday(profile.birthday) : null,
    createdAt: profile.createdAt,
    counts,
    ranks,
    achievements: Object.keys(profile.achievements ?? {}),
  });
}
