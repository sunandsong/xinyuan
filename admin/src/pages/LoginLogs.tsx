import { useState } from 'react';
import { Input, Select, Space } from 'antd';
import AdminTable from '../components/AdminTable';
import EmptyState from '../components/EmptyState';
import TablePage from '../components/TablePage';
import { MUTED } from '../theme';
import { fmtTime, usePagedList } from '../paged';

interface LoginRow {
  _id: string;
  uid: string;
  at: number;
  device?: string | null;
  os?: string | null;
  appVersion?: string | null;
  ip?: string | null;
}

export default function LoginLogs() {
  const [uid, setUid] = useState('');
  const [days, setDays] = useState('');
  const { items, pagination, loading } = usePagedList<LoginRow>('/admin/logins', { uid, days });

  return (
    <TablePage
      toolbar={
        <Space wrap>
          <Input.Search placeholder="按 uid 过滤" allowClear style={{ width: 240 }} onSearch={setUid} />
          <Select
            value={days}
            style={{ width: 120 }}
            onChange={setDays}
            options={[
              { value: '', label: '全部时间' },
              { value: '7', label: '近 7 天' },
              { value: '30', label: '近 30 天' },
            ]}
          />
          <span style={{ color: MUTED, fontSize: 13 }}>共 {pagination.total} 条记录</span>
        </Space>
      }
    >
      <AdminTable<LoginRow>
        rowKey="_id"
        loading={loading}
        dataSource={items}
        size="middle"
        locale={{ emptyText: <EmptyState height={160}>暂无登录记录</EmptyState> }}
        paginationBind={pagination}
        columns={[
          { title: '时间', dataIndex: 'at', width: 150, render: fmtTime },
          { title: '用户', dataIndex: 'uid', render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
          { title: '设备', dataIndex: 'device', render: (v) => v ?? '—' },
          { title: '系统', dataIndex: 'os', render: (v) => v ?? '—' },
          { title: 'App 版本', dataIndex: 'appVersion', render: (v) => v ?? '—' },
          { title: 'IP', dataIndex: 'ip', render: (v) => v ?? '—' },
        ]}
      />
    </TablePage>
  );
}
