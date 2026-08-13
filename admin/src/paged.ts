import { useEffect, useState } from 'react';
import { message } from 'antd';
import { api } from './api';
import { DEFAULT_TABLE_PAGE_SIZE, type PaginationBind } from './tableConfig';

/** 服务端分页列表：query 变了自动回第一页重拉 */
export function usePagedList<T>(
  basePath: string,
  query: Record<string, string> = {},
  initialPageSize = DEFAULT_TABLE_PAGE_SIZE,
) {
  const [items, setItems] = useState<T[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(initialPageSize);
  const [loading, setLoading] = useState(false);
  const [tick, setTick] = useState(0);

  const qs = Object.entries(query)
    .filter(([, v]) => v !== '')
    .map(([k, v]) => `${k}=${encodeURIComponent(v)}`)
    .join('&');

  useEffect(() => {
    setPage(1);
  }, [qs, pageSize]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    const sep = qs ? '&' : '';
    api
      .get(`${basePath}?${qs}${sep}skip=${(page - 1) * pageSize}&limit=${pageSize}`)
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

  function onPageChange(nextPage: number, nextSize: number) {
    if (nextSize !== pageSize) setPageSize(nextSize);
    setPage(nextSize !== pageSize ? 1 : nextPage);
  }

  const pagination: PaginationBind = { page, pageSize, total, onChange: onPageChange };

  return { items, total, page, pageSize, onPageChange, pagination, loading, reload: () => setTick((t) => t + 1) };
}

/** 客户端分页（一次拉全量的小表） */
export function useClientPagination<T>(items: T[] | null) {
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(DEFAULT_TABLE_PAGE_SIZE);
  const total = items?.length ?? 0;

  useEffect(() => {
    setPage(1);
  }, [total, pageSize]);

  function onPageChange(nextPage: number, nextSize: number) {
    if (nextSize !== pageSize) setPageSize(nextSize);
    setPage(nextSize !== pageSize ? 1 : nextPage);
  }

  const pageItems = items ? items.slice((page - 1) * pageSize, page * pageSize) : [];
  const pagination: PaginationBind = { page, pageSize, total, onChange: onPageChange };

  return { pageItems, pagination, loading: items === null };
}

export function fmtTime(ts?: number): string {
  if (!ts) return '—';
  const d = new Date(ts);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}.${p(d.getMonth() + 1)}.${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}
