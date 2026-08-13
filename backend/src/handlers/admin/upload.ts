// 管理端图片直传凭证：复刻用户端 upload.ts 的换凭证逻辑，鉴权走 X-Admin-Key
// （路由挂在 /admin 下，进来前已过 requireAdmin）。内容素材统一放 content/ 目录，
// 跟用户照片的 wishes/{uid}/ 隔开。
import { ENV_ID } from '../../config';
import { bad, ok, Req } from '../../http';
import { resolveStablePhotoUrls } from '../../photo-resolve';

const EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/heic': 'heic',
  'image/webp': 'webp',
};

/** POST /admin/upload —— body: { mime }，只换一次性直传凭证，图片本体走 COS 直传 */
export async function adminUpload(req: Req) {
  const mime = String(req.body?.mime ?? 'image/jpeg').toLowerCase();
  const ext = EXT[mime];
  if (!ext) return bad('unsupported_type');

  const cloudPath = `content/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;

  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const cloudbase = require('@cloudbase/node-sdk');
  const app = cloudbase.init({ env: ENV_ID });
  const meta = await app.getUploadMetadata({ cloudPath });
  const { url, token, authorization, cosFileId, download_url } = meta.data;
  return ok({
    cloudPath,
    url,
    headers: {
      Signature: authorization,
      authorization,
      'x-cos-security-token': token,
      'x-cos-meta-fileid': cosFileId,
      key: encodeURIComponent(cloudPath),
    },
    downloadUrl: download_url,
  });
}

/** POST /admin/photo-urls —— 管理端换用户照片/头像的临时访问链接 */
export async function adminPhotoUrls(req: Req) {
  const list = Array.isArray(req.body?.urls) ? req.body.urls.map(String) : [];
  if (list.length === 0 || list.length > 50) return bad('invalid_urls');
  const urls = await resolveStablePhotoUrls(list);
  return ok({ urls });
}
