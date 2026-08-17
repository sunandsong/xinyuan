import { useState } from 'react';
import { Alert, Button, message, Popconfirm, Select, Space, Tag, Typography } from 'antd';
import AdminTable from '../components/AdminTable';
import EmptyState from '../components/EmptyState';
import TablePage from '../components/TablePage';
import { api } from '../api';
import { MUTED } from '../theme';
import { fmtTime, usePagedList } from '../paged';

interface DeletionRow {
  _id: string;
  uid: string;
  account: string;
  nickname?: string;
  handled?: boolean;
  handledAt?: number;
  createdAt: number;
}

export default function DeletionRequests() {
  const [handled, setHandled] = useState('false');
  const { items, pagination, loading, reload } = usePagedList<DeletionRow>(
    '/admin/deletion-requests',
    { handled },
  );
  const [busy, setBusy] = useState('');

  /** 执行注销：先真删账号，再把申请打成已处理。
   * 顺序不能反——先标已处理再删，中间挂了这条申请就从列表里消失了，没人再管它。 */
  async function run(row: DeletionRow) {
    setBusy(row._id);
    try {
      await api.post(`/admin/users/${row.uid}/delete`);
      await api.post('/admin/content/deletion_requests', {
        id: row._id,
        doc: { handled: true, handledAt: Date.now() },
      });
      message.success(`已注销「${row.account}」`);
      reload();
    } catch (e: any) {
      message.error(`注销失败：${e.message}`);
    } finally {
      setBusy('');
    }
  }

  /** 只打标记不删号：账号早就注销过、或核实后判断不该受理时用 */
  async function markOnly(row: DeletionRow) {
    setBusy(row._id);
    try {
      await api.post('/admin/content/deletion_requests', {
        id: row._id,
        doc: { handled: true, handledAt: Date.now() },
      });
      message.success('已标记处理');
      reload();
    } catch (e: any) {
      message.error(`操作失败：${e.message}`);
    } finally {
      setBusy('');
    }
  }

  return (
    <TablePage
      toolbar={
        <Space wrap>
          <Select
            value={handled}
            style={{ width: 150 }}
            onChange={setHandled}
            options={[
              { value: 'false', label: '待处理' },
              { value: 'true', label: '已处理' },
              { value: '', label: '全部' },
            ]}
          />
          <span style={{ color: MUTED, fontSize: 13 }}>共 {pagination.total} 条</span>
        </Space>
      }
    >
      <Alert
        type="warning"
        showIcon
        style={{ marginBottom: 12 }}
        message="申请人已经在网页上通过密码验证，身份不用再核实，点「执行注销」即可"
        description="页面上向用户承诺的是 30 天内完成。申请堆着不处理会违反 Google Play 的账号删除要求，也可能导致下架。"
      />
      <AdminTable<DeletionRow>
        rowKey="_id"
        loading={loading}
        dataSource={items}
        size="middle"
        locale={{ emptyText: <EmptyState height={160}>没有待处理的注销申请</EmptyState> }}
        paginationBind={pagination}
        columns={[
          {
            title: '账号',
            dataIndex: 'account',
            render: (v: string, r) => (
              <div>
                <code style={{ fontSize: 13 }}>{v}</code>
                {r.nickname && (
                  <div style={{ color: MUTED, fontSize: 12, marginTop: 2 }}>{r.nickname}</div>
                )}
              </div>
            ),
          },
          { title: '提交时间', dataIndex: 'createdAt', width: 160, render: fmtTime },
          {
            title: '状态',
            dataIndex: 'handled',
            width: 150,
            render: (v: boolean | undefined, r) =>
              v ? (
                <span>
                  <Tag color="green">已处理</Tag>
                  {r.handledAt && (
                    <span style={{ color: MUTED, fontSize: 12 }}>{fmtTime(r.handledAt)}</span>
                  )}
                </span>
              ) : (
                <Tag color="gold">待处理</Tag>
              ),
          },
          {
            title: '操作',
            width: 200,
            render: (_: unknown, r) =>
              r.handled ? null : (
                <Space>
                  <Popconfirm
                    title={`确认注销「${r.account}」？`}
                    description="账号将无法再登录，名下心愿、任务、时光胶囊一并删除。"
                    okButtonProps={{ danger: true }}
                    onConfirm={() => run(r)}
                  >
                    <Button size="small" danger loading={busy === r._id}>
                      执行注销
                    </Button>
                  </Popconfirm>
                  <Typography.Link
                    style={{ fontSize: 13 }}
                    onClick={() => markOnly(r)}
                    disabled={busy === r._id}
                  >
                    仅标记
                  </Typography.Link>
                </Space>
              ),
          },
        ]}
      />
    </TablePage>
  );
}
