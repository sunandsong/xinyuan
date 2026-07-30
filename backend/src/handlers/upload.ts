// 图片上传：客户端传 base64，服务端落到 CloudBase 云存储，返回可直接展示的地址。
// mock 模式不打云，原样把 data URI 回给客户端，本地联调也能看到图。
import { ENV_ID, IS_MOCK } from '../config';
import { bad, ok, Req } from '../http';

/** 允许的图片类型 → 扩展名 */
const EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/heic': 'heic',
  'image/webp': 'webp',
};

// 云函数请求体本身有上限，这里再挡一道（base64 比原图大 ~33%）
const MAX_BYTES = 4 * 1024 * 1024;

/** POST /api/upload —— body: { data: <base64>, mime: 'image/jpeg', wishId?: string } */
export async function upload(req: Req, uid: string) {
  const body = (req.body ?? {}) as { data?: string; mime?: string; wishId?: string };
  const mime = (body.mime ?? 'image/jpeg').toLowerCase();
  const ext = EXT[mime];
  if (!ext) return bad('unsupported_type');

  // 兼容客户端直接传完整 data URI 的情况
  const raw = (body.data ?? '').replace(/^data:[^;]+;base64,/, '');
  if (!raw) return bad('empty_file');

  let buf: Buffer;
  try {
    buf = Buffer.from(raw, 'base64');
  } catch {
    return bad('bad_base64');
  }
  if (buf.length === 0) return bad('empty_file');
  if (buf.length > MAX_BYTES) return bad('file_too_large');

  const cloudPath = `wishes/${uid}/${Date.now()}-${Math.random()
    .toString(36)
    .slice(2, 8)}.${ext}`;

  if (IS_MOCK) {
    // 本地开发：不落存储，直接把图原样回给客户端
    return ok({ url: `data:${mime};base64,${raw}`, cloudPath, mock: true });
  }

  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const cloudbase = require('@cloudbase/node-sdk');
  const app = cloudbase.init({ env: ENV_ID });
  const res = await app.uploadFile({ cloudPath, fileContent: buf });
  const fileID: string = res.fileID;

  // 换成带签名的临时链接给客户端展示；拿不到就退回 fileID（客户端会当作不可展示处理）
  let url = fileID;
  try {
    const t = await app.getTempFileURL({ fileList: [fileID] });
    url = t.fileList?.[0]?.tempFileURL || fileID;
  } catch {
    /* 忽略：临时链接失败不影响文件已上传 */
  }
  return ok({ url, fileID, cloudPath });
}
