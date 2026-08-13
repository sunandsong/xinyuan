import { useState } from 'react';
import { Input, Popconfirm, Tag, message } from 'antd';
import { api } from '../api';
import { FormField } from '../components/AdminForm';
import AdminModal from '../components/AdminModal';
import AdminTable from '../components/AdminTable';
import EmptyState from '../components/EmptyState';
import { ActionBtn, TableActions } from '../components/TableActions';
import TablePage from '../components/TablePage';
import { MUTED } from '../theme';
import { fmtTime, usePagedList } from '../paged';

interface FeedbackRow {
  _id: string;
  uid: string;
  content: string;
  createdAt: number;
  handled?: boolean;
  note?: string;
}

export default function Feedback() {
  const { items, pagination, loading, reload } = usePagedList<FeedbackRow>('/admin/feedback', {});
  const [noteRow, setNoteRow] = useState<FeedbackRow | null>(null);
  const [noteText, setNoteText] = useState('');
  const [saving, setSaving] = useState(false);
  const openCount = items.filter((r) => !r.handled).length;

  async function toggleHandled(row: FeedbackRow) {
    try {
      await api.post(`/admin/feedback/${row._id}`, { handled: !row.handled });
      message.success(row.handled ? '已标回未处理' : '已标记处理');
      reload();
    } catch (e: any) {
      message.error(`操作失败：${e.message}`);
    }
  }

  async function saveNote() {
    if (!noteRow) return;
    setSaving(true);
    try {
      await api.post(`/admin/feedback/${noteRow._id}`, { note: noteText });
      message.success('备注已保存');
      setNoteRow(null);
      reload();
    } catch (e: any) {
      message.error(`保存失败：${e.message}`);
    } finally {
      setSaving(false);
    }
  }

  async function remove(id: string) {
    try {
      await api.post(`/admin/feedback/${id}/delete`);
      message.success('已删除');
      reload();
    } catch (e: any) {
      message.error(`删除失败：${e.message}`);
    }
  }

  return (
    <TablePage
      subtitle={
        <>
          共 {pagination.total} 条反馈{openCount > 0 ? `，本页待处理 ${openCount} 条` : ''}
        </>
      }
    >
      <AdminTable<FeedbackRow>
        rowKey="_id"
        loading={loading}
        dataSource={items}
        size="middle"
        locale={{ emptyText: <EmptyState height={160}>暂无反馈</EmptyState> }}
        paginationBind={pagination}
        columns={[
          { title: '时间', dataIndex: 'createdAt', width: 150, render: fmtTime },
          { title: '用户', dataIndex: 'uid', width: 170, render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
          { title: '内容', dataIndex: 'content', render: (v) => <div style={{ whiteSpace: 'pre-wrap' }}>{v}</div> },
          {
            title: '状态',
            dataIndex: 'handled',
            width: 90,
            render: (v) => (v ? <Tag color="green">已处理</Tag> : <Tag color="orange">待处理</Tag>),
          },
          { title: '备注', dataIndex: 'note', width: 180, render: (v) => v || <span style={{ color: MUTED }}>—</span> },
          {
            title: '操作',
            width: 220,
            render: (_, row) => (
              <TableActions>
                <ActionBtn onClick={() => toggleHandled(row)}>
                  {row.handled ? '标未处理' : '标已处理'}
                </ActionBtn>
                <ActionBtn
                  onClick={() => {
                    setNoteRow(row);
                    setNoteText(row.note ?? '');
                  }}
                >
                  备注
                </ActionBtn>
                <Popconfirm title="删除这条反馈？" onConfirm={() => remove(row._id)}>
                  <ActionBtn variant="danger">删除</ActionBtn>
                </Popconfirm>
              </TableActions>
            ),
          },
        ]}
      />
      <AdminModal
        title="处理备注"
        open={noteRow !== null}
        onCancel={() => setNoteRow(null)}
        onOk={saveNote}
        confirmLoading={saving}
        width={480}
      >
        <FormField label="备注" hint="最多 1000 字">
          <Input.TextArea rows={4} maxLength={1000} showCount value={noteText} onChange={(e) => setNoteText(e.target.value)} />
        </FormField>
      </AdminModal>
    </TablePage>
  );
}
