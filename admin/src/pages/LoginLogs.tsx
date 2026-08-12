import { useState } from 'react';
import { Input, Select, Space, Table } from 'antd';
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
  const { items, total, page, setPage, loading } = usePagedList<LoginRow>('/admin/logins', 20, {
    uid,
    days,
  });

  return (
    <div style={{ padding: 24 }}>
      <Space style={{ marginBottom: 16 }}>
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
      </Space>
      <Table<LoginRow>
        rowKey="_id"
        loading={loading}
        dataSource={items}
        pagination={{
          current: page,
          pageSize: 20,
          total,
          showSizeChanger: false,
          showTotal: (t) => `共 ${t} 条`,
          onChange: setPage,
        }}
        columns={[
          { title: '时间', dataIndex: 'at', width: 150, render: fmtTime },
          { title: '用户', dataIndex: 'uid', render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
          { title: '设备', dataIndex: 'device', render: (v) => v ?? '—' },
          { title: '系统', dataIndex: 'os', render: (v) => v ?? '—' },
          { title: 'App 版本', dataIndex: 'appVersion', render: (v) => v ?? '—' },
          { title: 'IP', dataIndex: 'ip', render: (v) => v ?? '—' },
        ]}
      />
    </div>
  );
}
