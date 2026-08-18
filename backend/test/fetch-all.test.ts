// 全表扫描的翻页逻辑。
//
// 为什么值得单独测：以前 all* 方法是单次 .limit(1000)，超过一千条**不报错、只是少算**。
// 管理端首页的用户数/心愿数/DAU/留存全都基于这几个方法，静默截断意味着
// 「数字慢慢变得不对，而没有任何人会发现」。这类 bug 最贵。
//
// CloudDb 的构造函数会连真库，测不了；这里把翻页算法按同样的语义复刻一份来测——
// 验的是「翻到底才停」这个逻辑本身，以及边界条件对不对。
import { test } from 'node:test';
import assert from 'node:assert/strict';

const QUERY_LIMIT = 1000;
const MAX_SCAN_PAGES = 20;

/** 跟 CloudDb.fetchAll 同构：拉满就继续翻，没拉满就收工 */
async function fetchAll(
  get: (skip: number, limit: number) => Promise<any[]>,
): Promise<{ items: any[]; capped: boolean }> {
  const out: any[] = [];
  for (let page = 0; page < MAX_SCAN_PAGES; page++) {
    const batch = await get(page * QUERY_LIMIT, QUERY_LIMIT);
    out.push(...batch);
    if (batch.length < QUERY_LIMIT) return { items: out, capped: false };
  }
  return { items: out, capped: true };
}

/** 造一个有 n 条数据的假集合 */
function collection(n: number) {
  const all = Array.from({ length: n }, (_, i) => i);
  let calls = 0;
  return {
    get calls() {
      return calls;
    },
    fetch: async (skip: number, limit: number) => {
      calls++;
      return all.slice(skip, skip + limit);
    },
  };
}

test('少于一页：一次查询拿完，不多翻', async () => {
  const c = collection(309); // 当前线上未删除心愿的真实量级
  const { items, capped } = await fetchAll(c.fetch);
  assert.equal(items.length, 309);
  assert.equal(c.calls, 1, '没拉满就该停，不该白翻第二页');
  assert.equal(capped, false);
});

test('正好一页：要多翻一次才知道到底了', async () => {
  const c = collection(QUERY_LIMIT);
  const { items } = await fetchAll(c.fetch);
  assert.equal(items.length, QUERY_LIMIT);
  assert.equal(c.calls, 2, '拉满一页时无法断定有没有更多，必须再探一次');
});

test('超过一页：全部拿到，不再静默截断（这就是修的那个 bug）', async () => {
  const c = collection(2500);
  const { items } = await fetchAll(c.fetch);
  assert.equal(items.length, 2500, '旧实现这里只会返回 1000 条，而且不报错');
  assert.equal(c.calls, 3);
});

test('空集合：返回空数组，不炸', async () => {
  const c = collection(0);
  const { items, capped } = await fetchAll(c.fetch);
  assert.deepEqual(items, []);
  assert.equal(capped, false);
});

test('撞到防呆上限：会标记 capped，好让调用方打日志', async () => {
  const c = collection(MAX_SCAN_PAGES * QUERY_LIMIT + 1);
  const { items, capped } = await fetchAll(c.fetch);
  assert.equal(capped, true, '超上限必须能被察觉，不能悄悄返回部分数据');
  assert.equal(items.length, MAX_SCAN_PAGES * QUERY_LIMIT);
});

test('翻页不重不漏', async () => {
  const c = collection(2500);
  const { items } = await fetchAll(c.fetch);
  assert.equal(new Set(items).size, 2500, '有重复说明 skip 算错了');
  assert.equal(items[0], 0);
  assert.equal(items[2499], 2499, '最后一条也要在，说明没漏尾巴');
});
