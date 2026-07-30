// 数据模型类型（与 App 端 lib/data.dart 对应；详见 docs/backend-design.md §3）

export interface UserProfile {
  _id: string; // uid
  email: string;
  passwordHash?: string; // 仅服务端；绝不返回给客户端
  nickname: string;
  avatarEmoji: string | null;
  createdAt: number;
  updatedAt: number;
  deleted?: boolean;
}

export interface WishStep {
  id: string;
  title: string;
  done: boolean;
  doneAt: number | null;
}

export interface WishNote {
  id: string;
  text: string;
  at: number;
}

export interface Wish {
  _id: string;
  uid: string;
  title: string;
  color: string; // 十六进制，如 "F5D08C"
  desc: string | null;
  done: boolean;
  doneAt: number | null;
  quote: string | null;
  location: string | null;
  heroIndex: number | null;
  targetAt: number | null; // 想在这天之前做到
  steps?: WishStep[]; // 里程碑
  notes?: WishNote[]; // 过程笔记
  photos?: string[]; // 云存储图片地址
  createdAt: number;
  updatedAt: number;
  deleted: boolean;
}

export interface Task {
  _id: string;
  uid: string;
  title: string;
  day: string; // yyyy-MM-dd
  time: string | null;
  done: boolean;
  wishId: string | null;
  color: string;
  desc: string | null;
  createdAt: number;
  updatedAt: number;
  deleted: boolean;
}

export interface Letter {
  _id: string;
  uid: string;
  title: string;
  content: string;
  openAt: number; // 到期才能开启
  createdAt: number;
  updatedAt: number;
  deleted: boolean;
}

export interface EmailCode {
  _id: string;
  email: string;
  purpose: 'register';
  code: string;
  expiresAt: number;
  attempts: number;
  lastSentAt: number;
}

export interface Share {
  _id: string;
  code: string;
  uid: string;
  wishId: string;
  snapshot: { title: string; quote: string | null; color: string };
  views: number;
  createdAt: number;
  expireAt: number | null;
}

/** 同步：客户端上传的一条记录（部分字段，服务端补全归属与时间戳） */
export type SyncWish = Partial<Wish> & { _id: string; updatedAt: number };
export type SyncTask = Partial<Task> & { _id: string; updatedAt: number };
export type SyncLetter = Partial<Letter> & { _id: string; updatedAt: number };

export interface PushBody {
  wishes?: SyncWish[];
  tasks?: SyncTask[];
  letters?: SyncLetter[];
  profile?: Partial<UserProfile>;
}

export interface PullResult {
  now: number;
  wishes: Wish[];
  tasks: Task[];
  letters: Letter[];
  profile: UserProfile | null;
}
