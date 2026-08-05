// 汇总路由 + 鉴权：public 先匹配，其余需登录。
import { getUid } from './auth';
import * as auth from './handlers/auth';
import * as geocode from './handlers/geocode';
import { leaderboard } from './handlers/leaderboard';
import * as me from './handlers/me';
import * as share from './handlers/share';
import * as sync from './handlers/sync';
import { photoUrls, upload } from './handlers/upload';
import { dispatch, notFound, ok, Req, Res, route, unauthorized } from './http';

// 路由不带 /api 前缀：CloudBase HTTP 服务会剥掉 /api；本地请求也统一剥掉后匹配。
const publicRoutes = [
  route('GET', '/health', async () => ok({ ok: true })),
  route('POST', '/auth/register', (r) => auth.register(r)),
  route('POST', '/auth/login', (r) => auth.login(r)),
  route('GET', '/share/:code', (req, p) => share.getShare(req, p.code)),
];

function protectedRoutes(uid: string) {
  return [
    route('GET', '/me', (r) => me.getMe(r, uid)),
    route('GET', '/leaderboard', (r) => leaderboard(r, uid)),
    route('PATCH', '/me', (r) => me.patchMe(r, uid)),
    route('DELETE', '/auth/account', (r) => me.deleteAccount(r, uid)),
    route('GET', '/sync/pull', (r) => sync.pull(r, uid)),
    route('POST', '/sync/push', (r) => sync.push(r, uid)),
    route('POST', '/share', (r) => share.createShare(r, uid)),
    route('POST', '/upload', (r) => upload(r, uid)),
    route('POST', '/photo-urls', (r) => photoUrls(r, uid)),
    route('GET', '/geocode/reverse', (r) => geocode.reverseGeocode(r)),
  ];
}

export async function handle(req: Req): Promise<Res> {
  try {
    // 统一剥掉可能的 /api 前缀（本地带、云端已剥）
    const norm: Req = { ...req, path: req.path.replace(/^\/api(?=\/|$)/, '') || '/' };

    const pub = await dispatch(publicRoutes, norm);
    if (pub) return pub;

    const uid = await getUid(norm);
    if (!uid) return unauthorized();

    const prot = await dispatch(protectedRoutes(uid), norm);
    return prot ?? notFound();
  } catch (e: any) {
    return { statusCode: 500, headers: { 'content-type': 'application/json' }, body: JSON.stringify({ error: 'internal_error', message: String(e?.message ?? e) }) };
  }
}
