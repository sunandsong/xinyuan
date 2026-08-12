import { useMemo, useState, type ReactNode } from 'react';
import { Alert, Button, Input, Modal, Popconfirm, Space, Switch, Table, message } from 'antd';
import type { ColumnsType } from 'antd/es/table';
import { api } from '../api';
import { usePagedList } from '../paged';

/** 通用内容表 CRUD：分页 + f_ 等值过滤 + 新建/JSON 编辑 + 删除。
 * softDelete（wishes/tasks/letters 三张同步表）：删除是软删（upsert deleted:true），
 * 带「看已删除（可恢复）」开关，开关打开后行操作变「恢复」。
 * 内容配置表（Task 6 的十张）：物理删，无开关。 */
export default function CrudTable({
  col,
  columns,
  where = {},
  filters,
  createDefaults,
  softDelete = false,
  pageSize = 20,
}: {
  col: string;
  columns: ColumnsType<any>;
  /** 等值过滤（不带 f_ 前缀，这里统一加） */
  where?: Record<string, string>;
  /** 额外的筛选控件，渲染在工具栏左侧 */
  filters?: ReactNode;
  /** 新建时弹窗里的初始文档；不传则不显示新建按钮 */
  createDefaults?: () => Record<string, unknown>;
  softDelete?: boolean;
  pageSize?: number;
}) {
  const [showDeleted, setShowDeleted] = useState(false);

  const query = useMemo(() => {
    const q: Record<string, string> = {};
    for (const [k, v] of Object.entries(where)) if (v !== '') q[`f_${k}`] = v;
    // 同步表的记录 deleted 字段恒存在（App 端 toJson 总是写），等值过滤没有漏网之鱼
    if (softDelete) q.f_deleted = showDeleted ? 'true' : 'false';
    return q;
  }, [where, softDelete, showDeleted]);

  const { items, total, page, setPage, loading, reload } = usePagedList<any>(
    `/admin/content/${col}`,
    pageSize,
    query,
  );

  // JSON 编辑弹窗：null=关闭；id 为空串=新建
  const [editing, setEditing] = useState<{ id: string; text: string } | null>(null);
  const [jsonError, setJsonError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function openEdit(row?: any) {
    if (row) {
      const { _id, ...doc } = row;
      setEditing({ id: _id, text: JSON.stringify(doc, null, 2) });
    } else {
      setEditing({ id: '', text: JSON.stringify(createDefaults?.() ?? {}, null, 2) });
    }
    setJsonError(null);
  }

  async function save() {
    if (!editing) return;
    let doc: unknown;
    try {
      doc = JSON.parse(editing.text);
    } catch (e: any) {
      setJsonError(`JSON 不合法：${e.message}`);
      return;
    }
    if (!doc || typeof doc !== 'object' || Array.isArray(doc)) {
      setJsonError('必须是一个 JSON 对象');
      return;
    }
    setSaving(true);
    try {
      await api.post(`/admin/content/${col}`, { id: editing.id || undefined, doc });
      message.success(editing.id ? '已保存' : '已新建');
      setEditing(null);
      reload();
    } catch (e: any) {
      message.error(`保存失败：${e.message}`);
    } finally {
      setSaving(false);
    }
  }

  async function remove(id: string) {
    try {
      await api.post(`/admin/content/${col}/delete`, { id });
      message.success(softDelete ? '已软删（可在「看已删除」里恢复）' : '已删除');
      reload();
    } catch (e: any) {
      message.error(`删除失败：${e.message}`);
    }
  }

  async function restore(id: string) {
    try {
      await api.post(`/admin/content/${col}`, { id, doc: { deleted: false } });
      message.success('已恢复');
      reload();
    } catch (e: any) {
      message.error(`恢复失败：${e.message}`);
    }
  }

  const actionColumn = {
    title: '操作',
    width: 150,
    render: (_: unknown, row: any) => (
      <Space>
        <Button size="small" onClick={() => openEdit(row)}>
          编辑
        </Button>
        {softDelete && showDeleted ? (
          <Button size="small" onClick={() => restore(row._id)}>
            恢复
          </Button>
        ) : (
          <Popconfirm title={softDelete ? '软删这条记录？' : '删除这条记录？'} onConfirm={() => remove(row._id)}>
            <Button size="small" danger>
              {softDelete ? '软删' : '删'}
            </Button>
          </Popconfirm>
        )}
      </Space>
    ),
  };

  return (
    <div style={{ padding: 24 }}>
      <Space style={{ marginBottom: 16 }} wrap>
        {filters}
        {createDefaults && (
          <Button type="primary" onClick={() => openEdit()}>
            新建
          </Button>
        )}
        {softDelete && (
          <Space>
            <Switch checked={showDeleted} onChange={setShowDeleted} />
            <span>看已删除（可恢复）</span>
          </Space>
        )}
      </Space>
      <Table
        rowKey="_id"
        loading={loading}
        dataSource={items}
        pagination={{
          current: page,
          pageSize,
          total,
          showSizeChanger: false,
          showTotal: (t) => `共 ${t} 条`,
          onChange: setPage,
        }}
        columns={[...columns, actionColumn]}
      />
      <Modal
        title={editing?.id ? `编辑（${editing.id}）` : '新建'}
        open={editing !== null}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
        width={640}
      >
        {jsonError && <Alert type="error" message={jsonError} style={{ marginBottom: 8 }} />}
        <Input.TextArea
          rows={16}
          style={{ fontFamily: 'monospace', fontSize: 12 }}
          value={editing?.text ?? ''}
          onChange={(e) => {
            setEditing((cur) => (cur ? { ...cur, text: e.target.value } : cur));
            setJsonError(null);
          }}
        />
      </Modal>
    </div>
  );
}
