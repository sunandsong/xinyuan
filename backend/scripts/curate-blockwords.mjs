/**
 * 从 fwwdn/sensitive-stop-words 整理上线屏蔽词（百级，包含式匹配）。
 * 用法：node scripts/curate-blockwords.mjs
 * 输出：scripts/blockwords-launch.txt
 */
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SRC = join(__dirname, '.tmp-sensitive-words');

function readLines(file) {
  const p = join(SRC, file);
  if (!existsSync(p)) return [];
  return readFileSync(p, 'utf8')
    .split(/[\n,，]/)
    .map((s) => s.trim())
    .filter(Boolean);
}

/** 广告类里太泛、容易误伤心愿标题的，不上线 */
const AD_SKIP = new Set([
  '兼职', '招聘', '网络', 'QQ', '有意者', '到货', '本店', '代购', '扣扣', '客服',
  '微店', '兼值', '淘宝', 'LY', 'qq', 'QQ群', '加盟', '代理', '批发', '包邮',
  '厂家', '直销', '优惠', '特价', '秒杀', '团购', '刷单', '网赚', '赚钱',
]);

/** 太短或太泛、误伤率高的 */
const GLOBAL_SKIP = new Set([
  '小姐', // 会误伤「小姐姐」
  '网络',
  '炸药', // 保留更长短语，单词易误伤
]);

function norm(word) {
  return word.replace(/\s+/g, '').trim();
}

function ok(word) {
  const w = norm(word);
  if (w.length < 2) return false;
  if (GLOBAL_SKIP.has(w)) return false;
  if (/^https?:\/\//i.test(w)) return false;
  if (/^[a-zA-Z0-9._-]{1,3}$/.test(w)) return false;
  return true;
}

const buckets = {
  porn: readLines('色情类.txt'),
  politics: readLines('政治类.txt'),
  violence: readLines('涉枪涉爆违法信息关键词.txt'),
  ad: readLines('广告.txt').filter((w) => !AD_SKIP.has(norm(w))),
};

const all = new Set();
for (const [name, words] of Object.entries(buckets)) {
  let kept = 0;
  for (const w of words) {
    const n = norm(w);
    if (ok(n)) {
      all.add(n);
      kept++;
    }
  }
  console.log(`${name}: ${words.length} raw → ${kept} after norm/filter`);
}

const sorted = [...all].sort((a, b) => a.localeCompare(b, 'zh'));
const out = join(__dirname, 'blockwords-launch.txt');
writeFileSync(out, sorted.join('\n') + '\n', 'utf8');
console.log(`\n总计 ${sorted.length} 条 → ${out}`);
