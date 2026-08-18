// 数据留存清理的测试。这是全仓库最危险的代码——它会物理删除用户数据，
// 而且是定时无人值守跑的。比较符号写反一个就能把还在用的账号删光，
// 所以「该删的删掉」和「不该删的一条都不许动」两个方向都要覆盖。
import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { setDbForTest } from '../src/db';
import { RETENTION, runCleanup } from '../src/handlers/cleanup';
import { FakeDb } from './fake-db';

const DAY = 86_400_000;
const now = Date.now();
const daysAgo = (n: number) => now - n * DAY;

/** 开关打开状态的 sys_features 文档 */
const featuresOn = { _id: 'sys_features', cleanupEnabled: true };

let db: FakeDb;

function useDb(cols: Record<string, any[]>) {
  db = new FakeDb({ announcements: [featuresOn], ...cols });
  setDbForTest(db);
  return db;
}

beforeEach(() => setDbForTest(null));

test('开关关着：一条都不删', async () => {
  const d = new FakeDb({
    announcements: [{ _id: 'sys_features', cleanupEnabled: false }],
    logins: [{ _id: 'l1', at: daysAgo(999) }],
  });
  setDbForTest(d);

  const r = await runCleanup();
  assert.equal(r.skipped, true);
  assert.equal(d.count('logins'), 1, '开关关着时哪怕数据早就过期也不许动');
});

test('开关字段缺失（配置读不到）：按关处理，一条都不删', async () => {
  // 兜底方向跟 showRank 相反：会删数据的任务，配置异常时宁可不跑
  const d = new FakeDb({ announcements: [], logins: [{ _id: 'l1', at: daysAgo(999) }] });
  setDbForTest(d);

  const r = await runCleanup();
  assert.equal(r.skipped, true);
  assert.equal(d.count('logins'), 1);
});

test('force 可以在开关关着时强制跑一次（验证用）', async () => {
  const d = new FakeDb({
    announcements: [{ _id: 'sys_features', cleanupEnabled: false }],
    logins: [{ _id: 'l1', at: daysAgo(999) }],
  });
  setDbForTest(d);

  const r = await runCleanup(true);
  assert.notEqual(r.skipped, true);
  assert.equal(d.count('logins'), 0);
});

test('登录日志：只删过期的，没到期的原样留着', async () => {
  const d = useDb({
    logins: [
      { _id: 'old', at: daysAgo(RETENTION.loginDays + 1) },
      { _id: 'edge', at: daysAgo(RETENTION.loginDays - 1) }, // 差一天，不许删
      { _id: 'fresh', at: now },
    ],
  });

  const r = await runCleanup();
  assert.equal(r.logins, 1);
  assert.deepEqual(d.ids('logins').sort(), ['edge', 'fresh']);
});

test('崩溃按 lastAt 算，不是 firstAt——还在复发的老 bug 不许清', async () => {
  const d = useDb({
    crashes: [
      // 很久以前第一次出现，但最近还在崩：必须留着
      { _id: 'recurring', firstAt: daysAgo(999), lastAt: now },
      // 早就不崩了：可以清
      { _id: 'stale', firstAt: daysAgo(999), lastAt: daysAgo(RETENTION.crashDays + 1) },
    ],
  });

  const r = await runCleanup();
  assert.equal(r.crashes, 1);
  assert.deepEqual(d.ids('crashes'), ['recurring']);
});

test('反馈：未处理的永不清，哪怕比保留期还老', async () => {
  const d = useDb({
    feedback: [
      { _id: 'open', handled: false, createdAt: daysAgo(9999) },
      { _id: 'noflag', createdAt: daysAgo(9999) }, // 连字段都没有，也算未处理
      { _id: 'done', handled: true, createdAt: daysAgo(RETENTION.handledFeedbackDays + 1) },
    ],
  });

  const r = await runCleanup();
  assert.equal(r.feedback, 1);
  assert.deepEqual(d.ids('feedback').sort(), ['noflag', 'open'], '没处理完的用户意见一条都不能删');
});

test('注销用户：满保留期才物理删，连带清干净全部关联数据', async () => {
  const d = useDb({
    users: [{ _id: 'u1', account: 'gone', deleted: true, deletedAt: daysAgo(RETENTION.deletedUserGraceDays + 1) }],
    wishes: [{ _id: 'w1', uid: 'u1' }],
    tasks: [{ _id: 't1', uid: 'u1' }],
    letters: [{ _id: 'le1', uid: 'u1' }],
    logins: [{ _id: 'lo1', uid: 'u1', at: now }],
    events: [{ _id: 'e1', uid: 'u1', at: now }],
    feedback: [{ _id: 'f1', uid: 'u1', createdAt: now }],
    deletion_requests: [{ _id: 'dr1', uid: 'u1' }],
  });

  const r = await runCleanup();
  assert.equal(r.purgedUsers, 1);
  for (const c of ['users', 'wishes', 'tasks', 'letters', 'logins', 'events', 'feedback', 'deletion_requests']) {
    assert.equal(d.count(c), 0, `${c} 里该用户的数据没清干净`);
  }
});

test('注销未满保留期：一条都不许动', async () => {
  const d = useDb({
    users: [{ _id: 'u1', account: 'waiting', deleted: true, deletedAt: daysAgo(RETENTION.deletedUserGraceDays - 1) }],
    wishes: [{ _id: 'w1', uid: 'u1' }],
  });

  const r = await runCleanup();
  assert.equal(r.purgedUsers, 0);
  assert.equal(d.count('users'), 1, '还在后悔期内，不能删');
  assert.equal(d.count('wishes'), 1);
});

test('没注销的活跃用户：绝对不能被碰', async () => {
  const d = useDb({
    users: [
      { _id: 'alive', account: 'alive', createdAt: daysAgo(9999) }, // 老账号但没注销
      { _id: 'alive2', account: 'a2', deleted: false, deletedAt: daysAgo(9999) }, // 有残留时间戳但 deleted=false
    ],
    wishes: [{ _id: 'w1', uid: 'alive' }, { _id: 'w2', uid: 'alive2' }],
  });

  const r = await runCleanup();
  assert.equal(r.purgedUsers, 0);
  assert.equal(d.count('users'), 2, '活跃用户被误删了——这是最严重的失败');
  assert.equal(d.count('wishes'), 2);
});

test('老数据缺 deletedAt：补盖成当下重新计时，不当作很久以前删的直接清掉', async () => {
  const d = useDb({
    users: [{ _id: 'legacy', account: 'legacy', deleted: true }], // 没有 deletedAt
    wishes: [{ _id: 'w1', uid: 'legacy' }],
  });

  const r = await runCleanup();
  assert.equal(r.stampedUsers, 1);
  assert.equal(r.purgedUsers, 0, '补盖的当次不能马上删——那等于跳过了保留期');
  assert.equal(d.count('users'), 1);
  assert.equal(d.count('wishes'), 1);

  const u = d.cols.users[0];
  assert.ok(u.deletedAt >= now, 'deletedAt 应该被盖成当下');
});

test('崩溃记录只清 account 归属，不整条删（同指纹下还聚合着别人的崩溃）', async () => {
  const d = useDb({
    users: [{ _id: 'u1', account: 'gone', deleted: true, deletedAt: daysAgo(RETENTION.deletedUserGraceDays + 1) }],
    crashes: [{ _id: 'fp1', account: 'gone', count: 42, lastAt: now }],
  });

  await runCleanup();
  assert.equal(d.count('crashes'), 1, '崩溃记录不能整条删');
  assert.equal(d.cols.crashes[0].account, '', '归属信息要清掉');
  assert.equal(d.cols.crashes[0].count, 42, '聚合计数要保留');
});

test('每次运行有条数上限，不会一次删爆（云函数只有 20 秒）', async () => {
  const many = Array.from({ length: 400 }, (_, i) => ({
    _id: `l${i}`,
    at: daysAgo(RETENTION.loginDays + 1),
  }));
  const d = useDb({ logins: many });

  const r = await runCleanup();
  assert.ok(r.logins > 0 && r.logins < 400, `单次应该有上限，实际删了 ${r.logins}`);
  assert.ok(d.count('logins') > 0, '剩下的留给下次跑');
});
