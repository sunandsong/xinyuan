// 图片直传：CloudBase 的 HTTP 网关对请求体大小限得很死（实测约 100KB，
// 报错码 EXCEED_MAX_PAYLOAD_SIZE），base64 图片经这层网关根本传不过去。
// 所以这里只发一次性直传凭证，图片本体由客户端直接 PUT 到云存储，不经过这个云函数。
import { ENV_ID } from '../config';
import { bad, ok, Req } from '../http';
import { resolveStablePhotoUrls, stableUrlToFileId } from '../photo-resolve';

/** 允许的图片类型 → 扩展名 */
const EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/heic': 'heic',
  'image/webp': 'webp',
};

/** POST /api/upload —— body: { mime: 'image/jpeg' }，只换凭证，不接收图片本体 */
export async function upload(req: Req, uid: string) {
  const body = (req.body ?? {}) as { mime?: string };
  const mime = (body.mime ?? 'image/jpeg').toLowerCase();
  const ext = EXT[mime];
  if (!ext) return bad('unsupported_type');

  const cloudPath = `wishes/${uid}/${Date.now()}-${Math.random()
    .toString(36)
    .slice(2, 8)}.${ext}`;

  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const cloudbase = require('@cloudbase/node-sdk');
  const app = cloudbase.init({ env: ENV_ID });
  // getUploadMetadata 换来的是"这次上传"的一次性凭证：客户端凭它直接 PUT 到 COS，
  // 字段名和用法完全照抄 @cloudbase/node-sdk 自己 uploadFile() 的实现
  const meta = await app.getUploadMetadata({ cloudPath });
  // 注意：download_url 带的 ?sign= 是临时签名，几小时就过期。客户端存的是
  // 去掉签名的稳定链接，展示时走下面的 photoUrls 换新鲜链接。
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

/** POST /api/photo-urls —— body: { urls: string[] }（存的稳定链接，不带签名）。
 * 存进心愿里的下载链接签名会过期，展示时用这个接口换一批新鲜的临时链接。
 * 返回 { urls: { 稳定链接: 新鲜临时链接 } }。 */
export async function photoUrls(req: Req, uid: string) {
  const body = (req.body ?? {}) as { urls?: unknown };
  const list = Array.isArray(body.urls) ? body.urls.map(String) : [];
  if (list.length === 0 || list.length > 50) return bad('invalid_urls');

  const entries: Array<[string, string]> = [];
  for (const u of list) {
    const key = u.split('?')[0];
    const fileId = stableUrlToFileId(key, uid);
    if (fileId) entries.push([key, fileId]);
  }
  if (entries.length === 0) return ok({ urls: {} });

  const out = await resolveStablePhotoUrls(entries.map((e) => e[0]));
  return ok({ urls: out });
}
