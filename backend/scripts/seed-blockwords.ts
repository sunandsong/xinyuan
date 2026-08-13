/**
 * 把 scripts/blockwords-launch.txt 灌进 blockwords 集合（幂等，按 word 去重）。
 * 先跑：node scripts/curate-blockwords.mjs
 * 再跑：cd backend && npx ts-node scripts/seed-blockwords.ts
 */
import { execSync } from 'child_process';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const ENV_ID = 'renshengqingdan-d8feva5q55d12bab';
const LIST = join(__dirname, 'blockwords-launch.txt');

function initDb() {
  const raw = execSync('tcb secrets get --json', { encoding: 'utf8' });
  const { secretId, secretKey, token } = JSON.parse(raw).data;
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const cloudbase = require('@cloudbase/node-sdk');
  return cloudbase.init({ env: ENV_ID, secretId, secretKey, sessionToken: token }).database();
}

async function ensureCollection(db: any) {
  try {
    await db.createCollection('blockwords');
  } catch {
    /* exists */
  }
}

async function main() {
  if (!existsSync(LIST)) {
    console.error('缺少 blockwords-launch.txt，请先运行 node scripts/curate-blockwords.mjs');
    process.exit(1);
  }
  const words = readFileSync(LIST, 'utf8')
    .split('\n')
    .map((s) => s.trim())
    .filter(Boolean);
  const db = initDb();
  await ensureCollection(db);
  const existing = await db.collection('blockwords').limit(2000).get();
  const seen = new Set<string>((existing.data ?? []).map((d: any) => d.word));
  let created = 0;
  let skipped = 0;
  for (const word of words) {
    if (seen.has(word)) {
      skipped++;
      continue;
    }
    await db.collection('blockwords').add({ word });
    seen.add(word);
    created++;
    if (created % 100 === 0) console.log(`已写入 ${created}…`);
  }
  console.log(`完成：新增 ${created}，跳过 ${skipped}，词表共 ${words.length} 条`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
