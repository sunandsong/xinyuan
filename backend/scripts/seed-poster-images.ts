// 把 App 内置海报图上传到云存储 content/posters/，并回填 poster_* 表里空的 url 字段。
// 跑法：cd backend && npx ts-node scripts/seed-poster-images.ts
// 幂等：固定 cloudPath，可重复跑；只更新 url 为空的行。

import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

const ENV_ID = 'renshengqingdan-d8feva5q55d12bab';
const POSTER_DIR = path.join(__dirname, '../../frontend/assets/posters');

function initApp() {
  const raw = execSync('tcb secrets get --json', { encoding: 'utf8' });
  const { secretId, secretKey, token } = JSON.parse(raw).data;
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const cloudbase = require('@cloudbase/node-sdk');
  return cloudbase.init({ env: ENV_ID, secretId, secretKey, sessionToken: token });
}

async function uploadContentFile(app: any, localPath: string, cloudPath: string): Promise<string> {
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
      'Content-Type': 'image/jpeg',
    },
    body: buf,
  });
  if (!res.ok) throw new Error(`COS PUT ${cloudPath} → ${res.status}`);
  return String(download_url ?? '').split('?')[0];
}

async function patchCollection(
  app: any,
  db: any,
  col: string,
  files: string[],
) {
  const urls: string[] = [];
  for (const file of files) {
    const local = path.join(POSTER_DIR, file);
    if (!fs.existsSync(local)) throw new Error(`missing ${local}`);
    const cloudPath = `content/posters/${file}`;
    const stable = await uploadContentFile(app, local, cloudPath);
    urls.push(stable);
    console.log(`  ↑ ${file}`);
  }

  const { data } = await db.collection(col).limit(100).get();
  const rows = (data ?? []).sort((a: any, b: any) => (a.sort ?? 0) - (b.sort ?? 0));
  let patched = 0;
  for (let i = 0; i < rows.length && i < urls.length; i++) {
    const row = rows[i];
    if (row.url) {
      console.log(`  skip ${col} sort=${row.sort} (已有 url)`);
      continue;
    }
    await db.collection(col).doc(row._id).update({ url: urls[i] });
    patched++;
    console.log(`  ✓ ${col} sort=${row.sort}`);
  }
  console.log(`${col}: 回填 ${patched} 条`);
}

async function main() {
  const app = initApp();
  const db = app.database();

  console.log('poster_task …');
  await patchCollection(app, db, 'poster_task', [
    'bg1.jpg',
    'bg2.jpg',
    'bg3.jpg',
    'bg4.jpg',
    'bg5.jpg',
  ]);

  console.log('poster_wish …');
  await patchCollection(app, db, 'poster_wish', [
    'wish1.jpg',
    'wish2.jpg',
    'wish3.jpg',
    'wish4.jpg',
    'wish5.jpg',
  ]);

  console.log('poster_done …');
  await patchCollection(app, db, 'poster_done', ['wish3.jpg']);

  console.log('done');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
