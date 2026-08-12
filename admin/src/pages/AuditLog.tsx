import { Table, Tag } from 'antd';
import { fmtTime, usePagedList } from '../paged';

interface AuditRow {
  _id: string;
  action: string;
  target: string;
  detail?: unknown;
  at: number;
}

const ACTION_COLORS: Record<string, string> = {
  create: 'green',
  update: 'blue',
  delete: 'red',
  ban: 'red',
  unban: 'green',
  'reset-password': 'orange',
  'reset-profile': 'orange',
  grant: 'gold',
};

export default function AuditLog() {
  const { items, total, page, setPage, loading } = usePagedList<AuditRow>('/admin/audit', 50, {});

  return (
    <div style={{ padding: 24 }}>
      <Table<AuditRow>
        rowKey="_id"
        loading={loading}
        dataSource={items}
        pagination={{
          current: page,
          pageSize: 50,
          total,
          showSizeChanger: false,
          showTotal: (t) => `共 ${t} 条`,
          onChange: setPage,
        }}
        columns={[
          { title: '时间', dataIndex: 'at', width: 150, render: fmtTime },
          {
            title: '动作',
            dataIndex: 'action',
            width: 130,
            render: (v) => <Tag color={ACTION_COLORS[v] ?? 'default'}>{v}</Tag>,
          },
          { title: '对象', dataIndex: 'target', render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
          {
            title: '详情',
            dataIndex: 'detail',
            render: (v) =>
              v ? <code style={{ fontSize: 12 }}>{JSON.stringify(v)}</code> : <span style={{ color: '#ccc' }}>—</span>,
          },
        ]}
      />
    </div>
  );
}
