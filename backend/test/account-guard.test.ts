// 数据面账号状态闸门。
//
// 值得单独测的原因：这个判断错了不会报错、不会崩，只会**悄悄让已注销的账号继续读写**。
// 而「注销之后数据真的不再回来」是我们对应用商店和隐私政策做出的承诺，
// 一旦另一台还登着的设备能把本地数据推回去，承诺就是假的，而且没人会发现。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { accountBlocked } from '../src/handlers/account_guard';

test('正常账号：放行', () => {
  assert.equal(accountBlocked({}), null);
  assert.equal(accountBlocked({ banned: false, deleted: false }), null);
});

test('查不到 profile：放行，不把新用户挡在外面', () => {
  assert.equal(accountBlocked(null), null);
  assert.equal(accountBlocked(undefined), null);
});

test('已注销：401 + account_deleted（这就是修的那个洞）', () => {
  const r = accountBlocked({ deleted: true });
  assert.equal(r?.statusCode, 401);
  assert.equal(JSON.parse(r!.body).error, 'account_deleted');
});

test('封禁：维持原来的通用 401，不改客户端既有行为', () => {
  const r = accountBlocked({ banned: true });
  assert.equal(r?.statusCode, 401);
  assert.equal(JSON.parse(r!.body).error, 'unauthorized');
});

test('又封禁又注销：先按封禁报，只要拦住就行', () => {
  const r = accountBlocked({ banned: true, deleted: true });
  assert.equal(r?.statusCode, 401);
});
