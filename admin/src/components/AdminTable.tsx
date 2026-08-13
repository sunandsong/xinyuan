import { useLayoutEffect, useRef, useState } from 'react';
import { Table } from 'antd';
import type { TableProps } from 'antd';
import ContentCard from './ContentCard';
import { buildPagination, type PaginationBind } from '../tableConfig';

export default function AdminTable<T extends object>({
  paginationBind,
  className,
  scroll,
  ...props
}: TableProps<T> & { paginationBind?: PaginationBind | false }) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const [scrollY, setScrollY] = useState(360);

  useLayoutEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const calc = () => {
      const thead = el.querySelector('.ant-table-thead');
      const pagination = el.querySelector('.ant-table-pagination');
      const theadH = thead?.getBoundingClientRect().height ?? 47;
      const pagH = paginationBind === false ? 0 : pagination?.getBoundingClientRect().height ?? 56;
      setScrollY(Math.max(160, el.clientHeight - theadH - pagH - 1));
    };
    calc();
    const ro = new ResizeObserver(calc);
    ro.observe(el);
    return () => ro.disconnect();
  }, [paginationBind, props.loading, props.dataSource?.length]);

  return (
    <ContentCard className={`admin-table-card admin-table-fill${className ? ` ${className}` : ''}`}>
      <div ref={wrapRef} className="admin-table-inner">
        <Table
          {...props}
          scroll={{
            x: scroll?.x ?? 'max-content',
            y: scrollY,
            ...scroll,
          }}
          pagination={
            paginationBind === false ? false : paginationBind ? buildPagination(paginationBind) : undefined
          }
        />
      </div>
    </ContentCard>
  );
}
