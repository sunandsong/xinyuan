import { useSyncExternalStore } from 'react';

// 本地开发走 vite 代理（同源免 CORS，见 vite.config.ts）；线上直连 API 域名
export const API_BASE = import.meta.env.DEV
  ? '/api'
  : 'https://renshengqingdan-d8feva5q55d12bab-1258070735.ap-shanghai.app.tcloudbase.com/api';

const KEY_STORAGE = 'admin_key';

/** 401 时抛出，App 捕获后回退到门禁页 */
export class GateError extends Error {
  constructor() {
    super('unauthorized');
  }
}

type Listener = () => void;
let listeners: Listener[] = [];
function emitChange() {
  for (const l of listeners) l();
}
function subscribe(listener: Listener) {
  listeners.push(listener);
  return () => {
    listeners = listeners.filter((l) => l !== listener);
  };
}

export function getKey(): string | null {
  return localStorage.getItem(KEY_STORAGE);
}

export function setKey(key: string) {
  localStorage.setItem(KEY_STORAGE, key);
  emitChange();
}

export function clearKey() {
  localStorage.removeItem(KEY_STORAGE);
  emitChange();
}

/** 当前管理密钥，key 变化（登录/退出/401 被清）时自动重渲染 */
export function useKey(): string | null {
  return useSyncExternalStore(subscribe, getKey);
}

async function request(path: string, options: RequestInit = {}) {
  const key = getKey();
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...(key ? { 'X-Admin-Key': key } : {}),
      ...options.headers,
    },
  });
  if (res.status === 401) {
    clearKey();
    throw new GateError();
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw Object.assign(new Error(data.error ?? `http_${res.status}`), {
      status: res.status,
      data,
    });
  }
  return data;
}

export const api = {
  get: (path: string) => request(path),
  post: (path: string, body?: unknown) =>
    request(path, { method: 'POST', body: body !== undefined ? JSON.stringify(body) : undefined }),
};
