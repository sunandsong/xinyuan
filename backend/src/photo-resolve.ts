import { ENV_ID } from './config';

/** 稳定 COS 链接 → cloud:// fileID。
 * wishes/{uid}/… 用户照片（带 uid 时校验归属）；content/… 管理端内容素材。 */
export function stableUrlToFileId(u: string, uid?: string): string | null {
  let parsed: URL;
  try {
    parsed = new URL(u);
  } catch {
    return null;
  }
  const bucket = parsed.hostname.split('.')[0];
  const path = decodeURIComponent(parsed.pathname.replace(/^\//, ''));
  if (path.startsWith('wishes/')) {
    if (uid && !path.startsWith(`wishes/${uid}/`)) return null;
    return `cloud://${ENV_ID}.${bucket}/${path}`;
  }
  if (path.startsWith('content/')) {
    return `cloud://${ENV_ID}.${bucket}/${path}`;
  }
  return null;
}

/** 批量把稳定链接换成可访问的临时链接 */
export async function resolveStablePhotoUrls(list: string[]): Promise<Record<string, string>> {
  const entries: Array<[string, string]> = [];
  const seen = new Set<string>();
  for (const u of list) {
    const key = u.split('?')[0];
    if (!key || seen.has(key)) continue;
    seen.add(key);
    const fileId = stableUrlToFileId(key);
    if (fileId) entries.push([key, fileId]);
  }
  if (entries.length === 0) return {};

  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const cloudbase = require('@cloudbase/node-sdk');
  const app = cloudbase.init({ env: ENV_ID });
  const res = await app.getTempFileURL({ fileList: entries.map((e) => e[1]) });
  const out: Record<string, string> = {};
  (res.fileList ?? []).forEach(
    (f: { tempFileURL?: string; download_url?: string }, i: number) => {
      const u = f.tempFileURL || f.download_url;
      if (u) out[entries[i][0]] = u;
    },
  );
  return out;
}
