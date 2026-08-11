// 汇总路由 + 鉴权：public 先匹配，其余需登录。
import { getUid } from './auth';
import * as auth from './handlers/auth';
import { requireAdmin } from './handlers/admin/auth';
import * as content from './handlers/admin/content';
import * as demo from './handlers/admin/demo';
import * as queries from './handlers/admin/queries';
import * as adminUsers from './handlers/admin/users';
import { getConfig } from './handlers/config';
import { track } from './handlers/events';
import { submitFeedback } from './handlers/feedback';
import * as geocode from './handlers/geocode';
import {
  placeInsights,
  placeVisitors,
  wishCompleters,
  wishInsights,
  wishStats,
} from './handlers/insights';
import { leaderboard } from './handlers/leaderboard';
import * as me from './handlers/me';
import { getPublicProfile } from './handlers/profile';
import { releasesPage } from './handlers/releases';
import * as share from './handlers/share';
import * as sync from './handlers/sync';
import { photoUrls, upload } from './handlers/upload';
import { CORS_HEADERS, dispatch, notFound, ok, Req, Res, route, unauthorized } from './http';

// 路由不带 /api 前缀：CloudBase HTTP 服务会剥掉 /api；本地请求也统一剥掉后匹配。
const publicRoutes = [
  route('GET', '/health', async () => ok({ ok: true })),
  route('POST', '/auth/register', (r) => auth.register(r)),
  route('POST', '/auth/login', (r) => auth.login(r)),
  route('GET', '/share/:code', (req, p) => share.getShare(req, p.code)),
  route('GET', '/releases', () => releasesPage()),
];

// 管理端路由：都在 requireAdmin 校验通过之后才走到这里，见 handle()。
const adminRoutes = [
  route('GET', '/admin/ping', async () => ok({ pong: true })),
  route('GET', '/admin/content/:col', (r, p) => content.list(r, p.col)),
  route('POST', '/admin/content/:col', (r, p) => content.upsert(r, p.col)),
  route('POST', '/admin/content/:col/delete', (r, p) => content.remove(r, p.col)),
  route('GET', '/admin/stats', (r) => queries.stats(r)),
  route('GET', '/admin/users', (r) => queries.userList(r)),
  route('GET', '/admin/users/:uid', (r, p) => queries.userDetail(r, p.uid)),
  route('GET', '/admin/feedback', (r) => queries.feedbackList(r)),
  route('GET', '/admin/logins', (r) => queries.loginList(r)),
  route('GET', '/admin/events', (r) => queries.eventList(r)),
  route('POST', '/admin/users/:uid/reset-password', (r, p) => adminUsers.resetPassword(r, p.uid)),
  route('POST', '/admin/users/:uid/ban', (r, p) => adminUsers.ban(r, p.uid)),
  route('POST', '/admin/users/:uid/delete', (r, p) => adminUsers.remove(r, p.uid)),
  route('POST', '/admin/users/:uid/grant', (r, p) => adminUsers.grant(r, p.uid)),
  route('POST', '/admin/users/:uid/reset-profile', (r, p) => adminUsers.resetProfile(r, p.uid)),
  route('POST', '/admin/feedback/:id/delete', (r, p) => adminUsers.feedbackDelete(r, p.id)),
  route('POST', '/admin/feedback/:id', (r, p) => adminUsers.feedbackUpdate(r, p.id)),
  route('GET', '/admin/demo-users', (r) => demo.list(r)),
  route('POST', '/admin/demo-users', (r) => demo.upsert(r)),
  route('POST', '/admin/demo-users/mark', (r) => demo.mark(r)),
  route('POST', '/admin/demo-users/:uid/delete', (r, p) => demo.remove(r, p.uid)),
];

function protectedRoutes(uid: string) {
  return [
    route('GET', '/config', (r) => getConfig(r)),
    route('GET', '/me', (r) => me.getMe(r, uid)),
    route('GET', '/leaderboard', (r) => leaderboard(r, uid)),
    route('GET', '/insights/wishes', (r) => wishInsights(r)),
    route('GET', '/insights/places', (r) => placeInsights(r)),
    route('GET', '/insights/wishes/stats', (r) => wishStats(r, uid)),
    route('GET', '/insights/wishes/users', (r) => wishCompleters(r)),
    route('GET', '/insights/places/users', (r) => placeVisitors(r)),
    route('GET', '/users/:id', (r, p) => getPublicProfile(r, p.id)),
    route('PATCH', '/me', (r) => me.patchMe(r, uid)),
    route('DELETE', '/auth/account', (r) => me.deleteAccount(r, uid)),
    route('GET', '/sync/pull', (r) => sync.pull(r, uid)),
    route('POST', '/sync/push', (r) => sync.push(r, uid)),
    route('POST', '/share', (r) => share.createShare(r, uid)),
    route('POST', '/feedback', (r) => submitFeedback(r, uid)),
    route('POST', '/events', (r) => track(r, uid)),
    route('POST', '/upload', (r) => upload(r, uid)),
    route('POST', '/photo-urls', (r) => photoUrls(r, uid)),
    route('GET', '/geocode/reverse', (r) => geocode.reverseGeocode(r)),
  ];
}

export async function handle(req: Req): Promise<Res> {
  try {
    // 预检请求直接放行，不进鉴权
    if (req.method === 'OPTIONS') return { statusCode: 204, headers: CORS_HEADERS, body: '' };

    // 统一剥掉可能的 /api 前缀（本地带、云端已剥）
    const norm: Req = { ...req, path: req.path.replace(/^\/api(?=\/|$)/, '') || '/' };

    // /admin/* 独立鉴权体系（管理端 key），不复用用户 JWT
    if (norm.path.startsWith('/admin')) {
      const denied = requireAdmin(norm);
      if (denied) return denied;
      const admin = await dispatch(adminRoutes, norm);
      return admin ?? notFound();
    }

    const pub = await dispatch(publicRoutes, norm);
    if (pub) return pub;

    const uid = await getUid(norm);
    if (!uid) return unauthorized();

    const prot = await dispatch(protectedRoutes(uid), norm);
    return prot ?? notFound();
  } catch (e: any) {
    return {
      statusCode: 500,
      headers: { 'content-type': 'application/json', ...CORS_HEADERS },
      body: JSON.stringify({ error: 'internal_error', message: String(e?.message ?? e) }),
    };
  }
}
