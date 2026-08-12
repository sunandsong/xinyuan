import { useState } from 'react';
import { Button, Input, Modal, Popconfirm, Space, Table, Tag, message } from 'antd';
import { api } from '../api';
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
  const { items, total, page, setPage, loading, reload } = usePagedList<FeedbackRow>(
    '/admin/feedback',
    20,
    {},
  );
  const [noteRow, setNoteRow] = useState<FeedbackRow | null>(null);
  const [noteText, setNoteText] = useState('');
  const [saving, setSaving] = useState(false);

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
    <div style={{ padding: 24 }}>
      <Table<FeedbackRow>
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
          { title: '时间', dataIndex: 'createdAt', width: 150, render: fmtTime },
          { title: '用户', dataIndex: 'uid', width: 170, render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
          { title: '内容', dataIndex: 'content', render: (v) => <div style={{ whiteSpace: 'pre-wrap' }}>{v}</div> },
          {
            title: '状态',
            dataIndex: 'handled',
            width: 90,
            render: (v) => (v ? <Tag color="green">已处理</Tag> : <Tag color="orange">待处理</Tag>),
          },
          { title: '备注', dataIndex: 'note', width: 180, render: (v) => v || <span style={{ color: '#ccc' }}>—</span> },
          {
            title: '操作',
            width: 200,
            render: (_, row) => (
              <Space>
                <Button size="small" onClick={() => toggleHandled(row)}>
                  {row.handled ? '标未处理' : '标已处理'}
                </Button>
                <Button
                  size="small"
                  onClick={() => {
                    setNoteRow(row);
                    setNoteText(row.note ?? '');
                  }}
                >
                  备注
                </Button>
                <Popconfirm title="删除这条反馈？" onConfirm={() => remove(row._id)}>
                  <Button size="small" danger>
                    删
                  </Button>
                </Popconfirm>
              </Space>
            ),
          },
        ]}
      />
      <Modal
        title="处理备注"
        open={noteRow !== null}
        onCancel={() => setNoteRow(null)}
        onOk={saveNote}
        confirmLoading={saving}
      >
        <Input.TextArea rows={4} maxLength={1000} value={noteText} onChange={(e) => setNoteText(e.target.value)} />
      </Modal>
    </div>
  );
}
