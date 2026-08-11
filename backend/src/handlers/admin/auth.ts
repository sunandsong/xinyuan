import { ADMIN_KEY } from '../../config';
import { forbidden, Req, Res, unauthorized } from '../../http';

/** 管理鉴权：没配 ADMIN_KEY 宁可整体不可用也不能裸奔 */
export function requireAdmin(req: Req): Res | null {
  if (!ADMIN_KEY) return forbidden('admin_disabled');
  const key = String(req.headers?.['x-admin-key'] ?? '');
  if (key !== ADMIN_KEY) return unauthorized();
  return null;
}
