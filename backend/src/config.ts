// 只有一种运行模式：真连 CloudBase。数据一律上云，没有内存/假数据分支。

// CloudBase 环境 ID（部署时由环境变量注入；本地起服务也必须给）
export const ENV_ID = process.env.CLOUDBASE_ENV_ID || '';

// JWT 密钥。故意不给默认值：漏配时宁可起不来，也不能用一个公开常量签发 token
// ——那等于谁都能伪造任意用户身份，而且没有任何报错。
export const JWT_SECRET = (() => {
  const s = process.env.JWT_SECRET;
  if (!s) {
    throw new Error(
      '缺少 JWT_SECRET 环境变量。云函数在 cloudbaserc.json 里配；' +
        '本地跑：JWT_SECRET=$(openssl rand -hex 32) npm run dev',
    );
  }
  return s;
})();

// 集合名
export const COL = {
  users: 'users',
  wishes: 'wishes',
  tasks: 'tasks',
  letters: 'letters',
  shares: 'shares',
} as const;
