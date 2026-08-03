// 只有一种运行模式：真连 CloudBase。数据一律上云，没有内存/假数据分支。

// CloudBase 环境 ID（部署时由环境变量注入；本地起服务也必须给）
export const ENV_ID = process.env.CLOUDBASE_ENV_ID || '';

// JWT 密钥（生产必须用环境变量覆盖，勿用默认值）
export const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';

// 集合名
export const COL = {
  users: 'users',
  wishes: 'wishes',
  tasks: 'tasks',
  letters: 'letters',
  shares: 'shares',
} as const;
