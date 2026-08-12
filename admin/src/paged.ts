import { useEffect, useState } from 'react';
import { message } from 'antd';
import { api } from './api';

/** 服务端分页列表的取数样板：query 变了自动回第一页重拉 */
export function usePagedList<T>(basePath: string, pageSize: number, query: Record<string, string>) {
  const [items, setItems] = useState<T[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [tick, setTick] = useState(0); // 手动刷新计数：写操作后 reload() 重拉当前页

  const qs = Object.entries(query)
    .filter(([, v]) => v !== '')
    .map(([k, v]) => `${k}=${encodeURIComponent(v)}`)
    .join('&');

  useEffect(() => {
    setPage(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [qs]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    const sep = qs ? '&' : '';
    api
      .get(`${basePath}?${qs}${sep}skip=${(page - 1) * pageSize}`)
      .then((d) => {
        if (cancelled) return;
        setItems(d.items);
        setTotal(d.total);
      })
      .catch((e) => message.error(`加载失败：${e.message}`))
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [basePath, pageSize, qs, page, tick]);

  return { items, total, page, setPage, loading, reload: () => setTick((t) => t + 1) };
}

export function fmtTime(ts?: number): string {
  if (!ts) return '—';
  const d = new Date(ts);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}.${p(d.getMonth() + 1)}.${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}
