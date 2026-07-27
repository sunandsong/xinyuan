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
  emailCodes: 'email_codes',
} as const;

// 邮箱验证码规则
export const CODE_TTL_MS = 10 * 60 * 1000; // 有效期 10 分钟
export const CODE_RESEND_INTERVAL_MS = 60 * 1000; // 重发间隔 60 秒
export const CODE_MAX_ATTEMPTS = 5; // 最多允许验证失败次数

// SMTP（发验证码邮件用；mock 模式不真正发信，直接打到控制台）
export const SMTP_HOST = process.env.SMTP_HOST || '';
export const SMTP_PORT = Number(process.env.SMTP_PORT || 465);
export const SMTP_USER = process.env.SMTP_USER || '';
export const SMTP_PASS = process.env.SMTP_PASS || '';
export const SMTP_FROM = process.env.SMTP_FROM || SMTP_USER;
