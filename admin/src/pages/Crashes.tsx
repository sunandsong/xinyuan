import { useState } from 'react';
import { Select, Space, Tag, Typography } from 'antd';
import AdminTable from '../components/AdminTable';
import EmptyState from '../components/EmptyState';
import TablePage from '../components/TablePage';
import { MUTED } from '../theme';
import { fmtTime, usePagedList } from '../paged';

interface CrashRow {
  _id: string;
  kind: 'dart_error' | 'abnormal_exit';
  type: string;
  message: string;
  stack: string;
  count: number;
  firstAt: number;
  lastAt: number;
  firstVersion: string;
  lastVersion: string;
  lastPlatform: string;
  lastOsVersion: string;
  account?: string;
}

export default function Crashes() {
  const [kind, setKind] = useState('');
  const [days, setDays] = useState('');
  const { items, pagination, loading } = usePagedList<CrashRow>('/admin/crashes', { kind, days });

  return (
    <TablePage
      toolbar={
        <Space wrap>
          <Select
            value={kind}
            style={{ width: 190 }}
            onChange={setKind}
            options={[
              { value: '', label: '全部类型' },
              { value: 'dart_error', label: 'Dart 异常（有堆栈）' },
              { value: 'abnormal_exit', label: '异常退出（无堆栈）' },
            ]}
          />
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
          <span style={{ color: MUTED, fontSize: 13 }}>共 {pagination.total} 类崩溃（同一问题已按指纹归并）</span>
        </Space>
      }
    >
      <AdminTable<CrashRow>
        rowKey="_id"
        loading={loading}
        dataSource={items}
        size="middle"
        locale={{ emptyText: <EmptyState height={160}>暂无崩溃记录</EmptyState> }}
        paginationBind={pagination}
        expandable={{
          expandedRowRender: (r) => (
            <div style={{ padding: '4px 8px' }}>
              <Typography.Text type="secondary" style={{ fontSize: 12 }}>
                {r.message}
              </Typography.Text>
              <pre
                style={{
                  marginTop: 8,
                  maxHeight: 380,
                  overflow: 'auto',
                  background: '#F7F8FA',
                  borderRadius: 8,
                  padding: 12,
                  fontSize: 12,
                  lineHeight: 1.6,
                  whiteSpace: 'pre-wrap',
                }}
              >
                {r.stack || '（异常退出没有堆栈：进程已经没了，抓不到现场。想要原生崩溃堆栈需要接 xCrash/KSCrash 那类 native 方案）'}
              </pre>
              <Typography.Text type="secondary" style={{ fontSize: 12 }}>
                首次 {fmtTime(r.firstAt)}（{r.firstVersion}） · 末次 {fmtTime(r.lastAt)}（{r.lastVersion}）
                {r.account ? ` · 首次上报账号 ${r.account}` : ''}
              </Typography.Text>
            </div>
          ),
        }}
        columns={[
          {
            title: '次数',
            dataIndex: 'count',
            width: 80,
            render: (v: number) => <b style={{ fontSize: 15 }}>{v}</b>,
          },
          {
            title: '类型',
            dataIndex: 'kind',
            width: 110,
            render: (v: string) =>
              v === 'abnormal_exit' ? <Tag color="orange">异常退出</Tag> : <Tag color="red">Dart 异常</Tag>,
          },
          {
            title: '异常',
            dataIndex: 'type',
            render: (v: string, r) => (
              <div>
                <code style={{ fontSize: 12 }}>{v}</code>
                <div style={{ color: MUTED, fontSize: 12, marginTop: 2 }}>
                  {(r.message || '').slice(0, 80)}
                </div>
              </div>
            ),
          },
          { title: '末次出现', dataIndex: 'lastAt', width: 150, render: fmtTime },
          {
            title: '版本 / 平台',
            dataIndex: 'lastVersion',
            width: 150,
            render: (v: string, r) => (
              <span style={{ fontSize: 12 }}>
                {v} · {r.lastPlatform}
              </span>
            ),
          },
        ]}
      />
    </TablePage>
  );
}
