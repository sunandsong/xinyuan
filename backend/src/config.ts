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

// 高德逆地理编码 key（可选）：完成心愿定位时，系统自带的反地理编码在没有
// Google 服务的安卓机上用不了，用它兜底查地名。没配就直接跳过这条兜底，
// 不影响其它功能。
export const AMAP_KEY = process.env.AMAP_KEY || '';

// 管理端鉴权 key（可选，但没配就整个 /admin/* 直接 403，宁可不可用也不裸奔）
export const ADMIN_KEY = process.env.ADMIN_KEY || '';

// 腾讯云 API 密钥（本任务只声明，暂不使用；后续管理端调 CloudBase 管理 API 时用）
export const TC_SECRET_ID = process.env.TC_SECRET_ID || '';
export const TC_SECRET_KEY = process.env.TC_SECRET_KEY || '';

// 集合名
export const COL = {
  users: 'users',
  wishes: 'wishes',
  tasks: 'tasks',
  letters: 'letters',
  shares: 'shares',
  feedback: 'feedback',
} as const;
