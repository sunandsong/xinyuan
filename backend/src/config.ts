// 运行模式：mock（本地不打云，节省额度） | cloud（真连 CloudBase）
export type Mode = 'mock' | 'cloud';

export const MODE: Mode = (process.env.MODE as Mode) || 'cloud';
export const IS_MOCK = MODE === 'mock';

// CloudBase 环境 ID（cloud 模式下必填，部署时由环境变量注入）
export const ENV_ID = process.env.CLOUDBASE_ENV_ID || '';

// JWT 密钥（生产必须用环境变量覆盖，勿用默认值）
export const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';

// 集合名
export const COL = {
  users: 'users',
  wishes: 'wishes',
  tasks: 'tasks',
  shares: 'shares',
} as const;
