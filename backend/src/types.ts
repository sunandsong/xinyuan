// 数据模型类型（与 App 端 lib/data.dart 对应；详见 docs/backend-design.md §3）

export interface UserProfile {
  _id: string; // = CloudBase uid
  email: string;
  nickname: string;
  avatarEmoji: string | null;
  createdAt: number;
  updatedAt: number;
  deleted?: boolean;
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
  createdAt: number;
  updatedAt: number;
  deleted: boolean;
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

export interface PushBody {
  wishes?: SyncWish[];
  tasks?: SyncTask[];
  profile?: Partial<UserProfile>;
}

export interface PullResult {
  now: number;
  wishes: Wish[];
  tasks: Task[];
  profile: UserProfile | null;
}
