import { useState } from 'react';
import { Input, Select, Space } from 'antd';
import AdminTable from '../components/AdminTable';
import EmptyState from '../components/EmptyState';
import TablePage from '../components/TablePage';
import { MUTED } from '../theme';
import { fmtTime, usePagedList } from '../paged';

interface EventRow {
  _id: string;
  uid: string;
  event: string;
  props?: Record<string, unknown> | null;
  at: number;
}

export default function Events() {
  const [event, setEvent] = useState('');
  const [uid, setUid] = useState('');
  const [days, setDays] = useState('');
  const { items, pagination, loading } = usePagedList<EventRow>('/admin/events', { event, uid, days });

  return (
    <TablePage
      toolbar={
        <Space wrap>
          <Input.Search placeholder="按事件名过滤" allowClear style={{ width: 200 }} onSearch={setEvent} />
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
          <span style={{ color: MUTED, fontSize: 13 }}>共 {pagination.total} 条事件</span>
        </Space>
      }
    >
      <AdminTable<EventRow>
        rowKey="_id"
        loading={loading}
        dataSource={items}
        size="middle"
        locale={{ emptyText: <EmptyState height={160}>暂无行为事件</EmptyState> }}
        paginationBind={pagination}
        columns={[
          { title: '时间', dataIndex: 'at', width: 150, render: fmtTime },
          { title: '事件', dataIndex: 'event' },
          { title: '用户', dataIndex: 'uid', width: 170, render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
          {
            title: '属性',
            dataIndex: 'props',
            render: (v) =>
              v ? <code style={{ fontSize: 12 }}>{JSON.stringify(v)}</code> : <span style={{ color: MUTED }}>—</span>,
          },
        ]}
      />
    </TablePage>
  );
}
