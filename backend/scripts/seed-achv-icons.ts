// 把 App 内置勋章图标上传到云存储 content/honor/，并回填 achv_defs 表里空的 icon 字段。
// 跑法：cd backend && npx ts-node scripts/seed-achv-icons.ts

import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

const ENV_ID = 'renshengqingdan-d8feva5q55d12bab';
const HONOR_DIR = path.join(__dirname, '../../frontend/assets/img/honor');

function initApp() {
  const raw = execSync('tcb secrets get --json', { encoding: 'utf8' });
  const { secretId, secretKey, token } = JSON.parse(raw).data;
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const cloudbase = require('@cloudbase/node-sdk');
  return cloudbase.init({ env: ENV_ID, secretId, secretKey, sessionToken: token });
}

async function uploadContentFile(
  app: any,
  localPath: string,
  cloudPath: string,
  mime: string,
): Promise<string> {
  const buf = fs.readFileSync(localPath);
  const meta = await app.getUploadMetadata({ cloudPath });
  const { url, token, authorization, cosFileId, download_url } = meta.data;
  const res = await fetch(url, {
    method: 'PUT',
    headers: {
      Signature: authorization,
      authorization,
      'x-cos-security-token': token,
      'x-cos-meta-fileid': cosFileId,
      'Content-Type': mime,
    },
    body: buf,
  });
  if (!res.ok) throw new Error(`COS PUT ${cloudPath} → ${res.status}`);
  return String(download_url ?? '').split('?')[0];
}

async function main() {
  const app = initApp();
  const db = app.database();

  const slugs = fs
    .readdirSync(HONOR_DIR)
    .filter((f) => f.endsWith('.png'))
    .map((f) => f.replace(/\.png$/, ''));

  const { data } = await db.collection('achv_defs').limit(100).get();
  const rows: Array<{ _id: string; slug: string; icon?: string }> = data ?? [];

  let patched = 0;
  for (const row of rows) {
    if (row.icon) {
      console.log(`skip ${row.slug} (已有 icon)`);
      continue;
    }
    if (!slugs.includes(row.slug)) {
      console.warn(`warn: 无本地图标 ${row.slug}.png`);
      continue;
    }
    const local = path.join(HONOR_DIR, `${row.slug}.png`);
    const cloudPath = `content/honor/${row.slug}.png`;
    const stable = await uploadContentFile(app, local, cloudPath, 'image/png');
    await db.collection('achv_defs').doc(row._id).update({ icon: stable });
    patched++;
    console.log(`✓ ${row.slug}`);
  }

  console.log(`achv_defs: 回填 ${patched} 条`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
