// 汇总路由 + 鉴权：public 先匹配，其余需登录。
import { getUid } from './auth';
import * as me from './handlers/me';
import * as share from './handlers/share';
import * as sync from './handlers/sync';
import { dispatch, notFound, ok, Req, Res, route, unauthorized } from './http';

const publicRoutes = [
  route('GET', '/api/health', async () => ok({ ok: true })),
  route('GET', '/api/share/:code', (req, p) => share.getShare(req, p.code)),
];

function protectedRoutes(uid: string) {
  return [
    route('GET', '/api/me', (r) => me.getMe(r, uid)),
    route('PATCH', '/api/me', (r) => me.patchMe(r, uid)),
    route('DELETE', '/api/auth/account', (r) => me.deleteAccount(r, uid)),
    route('GET', '/api/sync/pull', (r) => sync.pull(r, uid)),
    route('POST', '/api/sync/push', (r) => sync.push(r, uid)),
    route('POST', '/api/share', (r) => share.createShare(r, uid)),
  ];
}

export async function handle(req: Req): Promise<Res> {
  try {
    const pub = await dispatch(publicRoutes, req);
    if (pub) return pub;

    const uid = await getUid(req);
    if (!uid) return unauthorized();

    const prot = await dispatch(protectedRoutes(uid), req);
    return prot ?? notFound();
  } catch (e: any) {
    return { statusCode: 500, headers: { 'content-type': 'application/json' }, body: JSON.stringify({ error: 'internal_error', message: String(e?.message ?? e) }) };
  }
}
