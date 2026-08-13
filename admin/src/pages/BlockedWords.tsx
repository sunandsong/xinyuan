import { useState } from 'react';
import { Button, Input, Popconfirm, Space, message } from 'antd';
import { api } from '../api';
import AdminTable from '../components/AdminTable';
import EmptyState from '../components/EmptyState';
import { ActionBtn, TableActions } from '../components/TableActions';
import TablePage from '../components/TablePage';
import { usePagedList } from '../paged';

interface WordDoc {
  _id: string;
  word: string;
}

/** 屏蔽词（blockwords）：命中就挡心愿标题上榜、昵称对外脱敏。 */
export default function BlockedWords() {
  const { items, pagination, loading, reload } = usePagedList<WordDoc>('/admin/content/blockwords', {});
  const [adding, setAdding] = useState(false);
  const [newWord, setNewWord] = useState('');

  async function add(word: string) {
    const w = word.trim();
    if (!w) return;
    setAdding(true);
    try {
      const dup = await api.get(`/admin/content/blockwords?f_word=${encodeURIComponent(w)}&limit=1`);
      if (dup.items?.length) {
        message.warning('已经有这个词了');
        return;
      }
      await api.post('/admin/content/blockwords', { doc: { word: w } });
      message.success('已添加');
      setNewWord('');
      reload();
    } catch (e: any) {
      message.error(`添加失败：${e.message}`);
    } finally {
      setAdding(false);
    }
  }

  async function remove(doc: WordDoc) {
    try {
      await api.post('/admin/content/blockwords/delete', { id: doc._id });
      message.success('已删除');
      reload();
    } catch (e: any) {
      message.error(`删除失败：${e.message}`);
    }
  }

  return (
    <TablePage
      toolbar={
        <Space className="admin-toolbar-field" size={8} align="center">
          <Input
            placeholder="输入新屏蔽词"
            value={newWord}
            allowClear
            onChange={(e) => setNewWord(e.target.value)}
            onPressEnter={() => add(newWord)}
          />
          <Button type="primary" loading={adding} onClick={() => add(newWord)}>
            添加
          </Button>
        </Space>
      }
    >
      <AdminTable<WordDoc>
        rowKey="_id"
        loading={loading}
        dataSource={items}
        size="middle"
        locale={{ emptyText: <EmptyState height={160}>暂无屏蔽词</EmptyState> }}
        paginationBind={pagination}
        columns={[
          {
            title: '#',
            width: 64,
            render: (_: unknown, __: WordDoc, index: number) =>
              (pagination.page - 1) * pagination.pageSize + index + 1,
          },
          { title: '屏蔽词', dataIndex: 'word' },
          {
            title: '操作',
            width: 88,
            render: (_: unknown, row: WordDoc) => (
              <TableActions>
                <Popconfirm title={`删除「${row.word}」？`} onConfirm={() => remove(row)}>
                  <ActionBtn variant="danger">删除</ActionBtn>
                </Popconfirm>
              </TableActions>
            ),
          },
        ]}
      />
    </TablePage>
  );
}
