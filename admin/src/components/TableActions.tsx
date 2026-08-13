import { Button, type ButtonProps } from 'antd';
import type { ReactNode } from 'react';

/** 表格行内操作区：统一间距与换行 */
export function TableActions({ children }: { children: ReactNode }) {
  return <div className="admin-table-actions">{children}</div>;
}

type ActionBtnProps = Omit<ButtonProps, 'type' | 'danger' | 'variant'> & {
  variant?: 'default' | 'primary' | 'danger';
};

/** 表格内操作按钮（不用 link / 纯文本） */
export function ActionBtn({ variant = 'default', className, size = 'small', ...props }: ActionBtnProps) {
  const extra =
    variant === 'primary'
      ? 'admin-action-btn--primary'
      : variant === 'danger'
        ? 'admin-action-btn--danger'
        : '';
  return (
    <Button
      size={size}
      type={variant === 'primary' ? 'primary' : 'default'}
      danger={variant === 'danger'}
      className={['admin-action-btn', extra, className].filter(Boolean).join(' ')}
      {...props}
    />
  );
}
