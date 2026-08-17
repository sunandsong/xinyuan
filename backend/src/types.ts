// 数据模型类型（与 App 端 lib/data.dart 对应；详见 docs/backend-design.md §3）

export interface UserProfile {
  _id: string; // uid
  account: string; // 登录账号（唯一）
  passwordHash?: string; // 仅服务端；绝不返回给客户端
  nickname: string;
  avatarEmoji: string | null;
  avatarUrl?: string | null; // 头像照片（云存储稳定链接），优先于 emoji
  gender?: string | null; // 性别：'男' / '女'，null = 没填
  birthday?: string | null; // 生日 'yyyy-MM-dd'，年龄由客户端按它计算
  achievements?: Record<string, number>; // 成就 slug → 点亮时间(ms)，拿到即永久
  checkins?: Record<string, number>; // 景区打卡：地点名 → 首次打卡时间(ms)
  // 排行榜用的 4 个计数：客户端随同步一起推上来，服务端不重算（重算要扫全表，太贵）
  doneCount?: number;  // 已实现心愿数
  taskCount?: number;  // 完成任务数
  achvCount?: number;  // 点亮奖杯数
  placeCount?: number; // 地图点亮地点数
  createdAt: number;
  updatedAt: number;
  deleted?: boolean;
  lastLoginAt?: number;
  lastActiveAt?: number;
  banned?: boolean; // 管理端封禁（Task 5）
  hideFromRank?: boolean; // 用户自选「不上榜」：排行榜/热度穿透都不出现（隐私开关）
  isDemo?: boolean; // 演示账号标记（Task 6）
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
  remind: boolean;
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

export interface Feedback {
  _id: string;
  uid: string;
  content: string;
  createdAt: number;
  handled?: boolean; // 管理端处理状态（Task 5）
  note?: string; // 管理端处理备注（Task 5）
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

/** 崩溃上报一条记录（客户端 crash_reporter 采集，服务端按指纹聚合） */
export interface CrashInfo {
  /** dart_error = Dart 层未捕获异常（有可读堆栈）；
   * native_crash = xCrash/KSCrash 抓到的原生崩溃（有堆栈但未符号化，是原始地址）；
   * abnormal_exit = 上面两者都没抓到、但靠「启动写标记、正常退出清除」推断出
   * 上次非正常结束（无堆栈，多半是被系统直接回收） */
  kind: 'dart_error' | 'native_crash' | 'abnormal_exit';
  /** 异常类型名，如 _TypeError；abnormal_exit 固定为 AbnormalExit */
  type: string;
  message: string;
  /** Dart 堆栈原文；abnormal_exit 没有 */
  stack: string;
  appVersion: string;
  platform: string;
  osVersion: string;
  /** 崩溃发生时间（客户端时钟），不是上报时间 */
  at: number;
  /** 登录账号，未登录时为空串（/crash 是公开路由，不解 JWT，拿不到 uid） */
  account: string;
}
