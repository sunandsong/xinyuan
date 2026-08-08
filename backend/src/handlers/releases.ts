// App 版本下载页：读 GitHub Releases（CI 每次 push 自动打包上传），
// 渲染成手机友好的 HTML 给合伙人直接下载安装。公开路由，不用登录。
// CI 若把 APK 同步传到了云存储（releases/ 目录），优先给国内高速链接。
import { ENV_ID } from '../config';
import { Res, serverError } from '../http';

const REPO = 'sunandsong/xinyuan';
/** 国内直连 GitHub 下载慢/失败时的加速镜像前缀 */
const MIRROR = 'https://gh-proxy.com/';

let cache: { at: number; html: string } | null = null;
let bucket: string | null = null; // 云存储桶名，跑一次探测后缓存

/** 云存储里 releases/ 下这些文件的临时下载链接（不存在的返回不了就没有）*/
async function fastUrls(names: string[]): Promise<Record<string, string>> {
  const out: Record<string, string> = {};
  if (names.length === 0) return out;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const cloudbase = require('@cloudbase/node-sdk');
    const app = cloudbase.init({ env: ENV_ID });
    if (!bucket) {
      // 桶名没法硬编码：借一次上传凭证的 download_url 把它探出来
      const meta = await app.getUploadMetadata({ cloudPath: 'releases/.probe' });
      bucket = new URL(meta.data.download_url).hostname.split('.')[0];
    }
    const res = await app.getTempFileURL({
      fileList: names.map((n) => `cloud://${ENV_ID}.${bucket}/releases/${n}`),
    });
    const candidates: Array<[string, string]> = [];
    (res.fileList ?? []).forEach((f: any, i: number) => {
      const u = f.tempFileURL || f.download_url;
      if (u) candidates.push([names[i], u]);
    });
    // 拿到链接不代表文件真的在（老版本可能没传过）：HEAD 验一下再上按钮
    await Promise.all(
      candidates.map(async ([n, u]) => {
        try {
          const h = await fetch(u, { method: 'HEAD' });
          if (h.ok) out[n] = u;
        } catch {}
      }),
    );
  } catch (e) {
    console.error('fast urls failed', e); // 云存储不可用就只给 GitHub 链接
  }
  return out;
}

export async function releasesPage(): Promise<Res> {
  try {
    // 5 分钟缓存：别每次打开页面都打 GitHub API（有匿名限流）
    if (!cache || Date.now() - cache.at > 5 * 60_000) {
      const r = await fetch(
        `https://api.github.com/repos/${REPO}/releases?per_page=20`,
        { headers: { 'user-agent': 'xinyuan-releases' } },
      );
      if (!r.ok) throw new Error(`github ${r.status}`);
      const list = (await r.json()) as any[];
      const fast = await fastUrls(
        list
          .slice(0, 5) // 只查最近 5 个版本，老的没必要
          .map((x) => x.assets?.find((a: any) => a.name.endsWith('.apk'))?.name)
          .filter(Boolean),
      );
      cache = { at: Date.now(), html: render(list, fast) };
    }
    return {
      statusCode: 200,
      headers: { 'content-type': 'text/html; charset=utf-8' },
      body: cache.html,
    };
  } catch (e) {
    console.error('releases page failed', e);
    return serverError('releases_unavailable');
  }
}

function esc(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function fmtDate(iso: string): string {
  const d = new Date(iso);
  // 北京时间
  const t = new Date(d.getTime() + 8 * 3600_000);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${t.getUTCFullYear()}.${p(t.getUTCMonth() + 1)}.${p(t.getUTCDate())} ${p(t.getUTCHours())}:${p(t.getUTCMinutes())}`;
}

function fmtSize(b: number): string {
  return b > 1024 * 1024 ? `${(b / 1024 / 1024).toFixed(1)} MB` : `${(b / 1024).toFixed(0)} KB`;
}

function render(list: any[], fast: Record<string, string>): string {
  const items = list
    .filter((r) => (r.assets ?? []).length > 0)
    .map((r, i) => {
      const asset = r.assets.find((a: any) => a.name.endsWith('.apk')) ?? r.assets[0];
      const notes = String(r.body ?? '').trim();
      const fastUrl = fast[asset.name];
      const mainBtn = fastUrl
        ? `<a class="btn" href="${fastUrl}">高速下载</a>`
        : `<a class="btn" href="${MIRROR}${asset.browser_download_url}">下载安装</a>`;
      const altLinks = fastUrl
        ? `<a class="alt" href="${MIRROR}${asset.browser_download_url}">高速链接不行？走镜像</a>`
        : `<a class="alt" href="${asset.browser_download_url}">镜像下载失败？试试直连</a>`;
      return `
      <div class="card">
        <div class="row">
          <div>
            <div class="name">${esc(r.name || r.tag_name)}${i === 0 ? '<span class="latest">最新</span>' : ''}</div>
            <div class="meta">${fmtDate(r.published_at)} · ${fmtSize(asset.size)}</div>
          </div>
          ${mainBtn}
        </div>
        ${notes ? `<div class="notes">${esc(notes).slice(0, 600)}</div>` : ''}
        ${altLinks}
      </div>`;
    })
    .join('\n');

  return `<!doctype html>
<html lang="zh">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>人生清单 · 版本下载</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, "PingFang SC", sans-serif; background: #f2f4f8; color: #22314a; padding: 20px 16px 40px; }
  h1 { font-size: 22px; text-align: center; margin: 14px 0 4px; }
  .sub { text-align: center; color: #8a93a6; font-size: 13px; margin-bottom: 20px; }
  .card { background: #fff; border-radius: 16px; padding: 16px; margin: 0 auto 12px; max-width: 560px; box-shadow: 0 2px 10px rgba(30,50,90,.06); }
  .row { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
  .name { font-size: 16px; font-weight: 600; }
  .latest { background: #e8f7f0; color: #2e8f6b; font-size: 11px; padding: 2px 8px; border-radius: 99px; margin-left: 8px; vertical-align: 2px; }
  .meta { color: #8a93a6; font-size: 12.5px; margin-top: 3px; }
  .btn { background: linear-gradient(135deg, #4fc79a, #2e8f6b); color: #fff; text-decoration: none; font-size: 14px; font-weight: 600; padding: 10px 18px; border-radius: 12px; white-space: nowrap; }
  .notes { color: #5d6b84; font-size: 13px; line-height: 1.6; margin-top: 10px; white-space: pre-wrap; border-top: 1px solid #eef1f6; padding-top: 10px; }
  .alt { display: block; margin-top: 10px; color: #8a93a6; font-size: 12px; text-decoration: none; }
  .tip { max-width: 560px; margin: 18px auto 0; color: #8a93a6; font-size: 12.5px; line-height: 1.7; }
  .empty { text-align: center; color: #8a93a6; padding: 60px 0; }
</style>
</head>
<body>
  <h1>人生清单</h1>
  <div class="sub">安卓安装包 · 每次代码更新自动打包</div>
  ${items || '<div class="empty">还没有发布的版本，推一次代码就有了</div>'}
  <div class="tip">
    安装提示：下载后打开 APK，系统若提示「不允许安装未知应用」，
    在弹出的设置里允许当前浏览器安装即可。iPhone 暂不支持网页安装，
    需要等 TestFlight（苹果开发者账号）就绪。
  </div>
</body>
</html>`;
}
