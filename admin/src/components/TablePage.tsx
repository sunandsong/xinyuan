import type { ReactNode } from 'react';

/** 表格页：占满内容区高度，工具栏在上、表格撑满剩余空间 */
export default function TablePage({
  toolbar,
  extra,
  subtitle,
  children,
}: {
  toolbar?: ReactNode;
  extra?: ReactNode;
  subtitle?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="admin-table-page">
      {extra}
      {subtitle ? <div className="admin-table-page__subtitle">{subtitle}</div> : null}
      {toolbar ? <div className="admin-table-page__toolbar">{toolbar}</div> : null}
      <div className="admin-table-page__main">{children}</div>
    </div>
  );
}
