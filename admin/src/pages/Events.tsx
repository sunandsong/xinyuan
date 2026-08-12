import { useState } from 'react';
import { Input, Select, Space, Table } from 'antd';
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
  const { items, total, page, setPage, loading } = usePagedList<EventRow>('/admin/events', 20, {
    event,
    uid,
    days,
  });

  return (
    <div style={{ padding: 24 }}>
      <Space style={{ marginBottom: 16 }}>
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
      </Space>
      <Table<EventRow>
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
          { title: '用户', dataIndex: 'uid', width: 170, render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
          { title: '事件', dataIndex: 'event' },
          {
            title: '参数',
            dataIndex: 'props',
            render: (v) =>
              v ? <code style={{ fontSize: 12 }}>{JSON.stringify(v)}</code> : <span style={{ color: '#ccc' }}>—</span>,
          },
        ]}
      />
    </div>
  );
}
