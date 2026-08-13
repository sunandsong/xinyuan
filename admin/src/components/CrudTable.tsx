import { useMemo, useState, type ReactNode, type RefObject } from 'react';
import { Alert, Button, Popconfirm, Space, Switch, message } from 'antd';
import type { ColumnsType } from 'antd/es/table';
import { api } from '../api';
import { usePagedList } from '../paged';
import AdminModal from './AdminModal';
import AdminTable from './AdminTable';
import EmptyState from './EmptyState';
import { ActionBtn, TableActions } from './TableActions';
import TablePage from './TablePage';

export interface CrudFormContext {
  where: Record<string, string>;
}

export interface CrudEditForm<V> {
  modalTitle: (ctx: { id: string; isNew: boolean }) => string;
  width?: number;
  defaults: (ctx: CrudFormContext) => V;
  fromRow: (row: Record<string, unknown> | null, ctx: CrudFormContext) => V;
  toDoc: (values: V, row: Record<string, unknown> | null, ctx: CrudFormContext) => Record<string, unknown>;
  validate?: (values: V) => string | null;
  Form: (props: { values: V; onChange: (patch: Partial<V>) => void }) => ReactNode;
}

/** 通用内容表 CRUD：分页 + f_ 等值过滤 + 表单编辑 + 删除。 */
export default function CrudTable<V = Record<string, unknown>>({
  col,
  columns,
  where = {},
  filters,
  editForm,
  creatable = false,
  softDelete = false,
  showActions = true,
  refreshRef,
  onData,
  subtitle,
  toolbarExtra,
  extra,
  embedded = false,
}: {
  col: string;
  columns: ColumnsType<any>;
  where?: Record<string, string>;
  filters?: ReactNode;
  editForm?: CrudEditForm<V>;
  creatable?: boolean;
  softDelete?: boolean;
  showActions?: boolean;
  refreshRef?: RefObject<(() => void) | null>;
  onData?: (items: any[]) => void;
  subtitle?: string;
  toolbarExtra?: ReactNode;
  extra?: ReactNode;
  embedded?: boolean;
}) {
  const [showDeleted, setShowDeleted] = useState(false);
  const formCtx = useMemo<CrudFormContext>(() => ({ where }), [where]);

  const query = useMemo(() => {
    const q: Record<string, string> = {};
    for (const [k, v] of Object.entries(where)) if (v !== '') q[`f_${k}`] = v;
    if (softDelete) q.f_deleted = showDeleted ? 'true' : 'false';
    return q;
  }, [where, softDelete, showDeleted]);

  const { items, pagination, loading, reload } = usePagedList<any>(`/admin/content/${col}`, query);
  if (refreshRef) refreshRef.current = reload;
  onData?.(items);

  const [editing, setEditing] = useState<{ id: string; row: Record<string, unknown> | null } | null>(null);
  const [values, setValues] = useState<V | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function openEdit(row?: Record<string, unknown>) {
    if (!editForm) return;
    setEditing({ id: String(row?._id ?? ''), row: row ?? null });
    setValues(editForm.fromRow(row ?? null, formCtx));
    setFormError(null);
  }

  async function save() {
    if (!editing || !editForm || !values) return;
    const err = editForm.validate?.(values);
    if (err) {
      setFormError(err);
      return;
    }
    setSaving(true);
    try {
      const doc = editForm.toDoc(values, editing.row, formCtx);
      if (formCtx.where.uid && !doc.uid) doc.uid = formCtx.where.uid;
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

  const actionColumn =
    showActions && editForm
      ? {
          title: '操作',
          width: softDelete ? 168 : 148,
          render: (_: unknown, row: any) => (
            <TableActions>
              <ActionBtn variant="primary" onClick={() => openEdit(row)}>
                编辑
              </ActionBtn>
              {softDelete && showDeleted ? (
                <ActionBtn onClick={() => restore(row._id)}>恢复</ActionBtn>
              ) : (
                <Popconfirm title={softDelete ? '软删这条记录？' : '删除这条记录？'} onConfirm={() => remove(row._id)}>
                  <ActionBtn variant="danger">{softDelete ? '软删除' : '删除'}</ActionBtn>
                </Popconfirm>
              )}
            </TableActions>
          ),
        }
      : null;

  const toolbar = filters || toolbarExtra || (creatable && editForm) || softDelete ? (
    <Space wrap>
      {filters}
      {toolbarExtra}
      {creatable && editForm && (
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
  ) : null;

  const EditForm = editForm?.Form;

  const table = (
    <>
      {embedded && toolbar ? <div className="admin-table-page__toolbar">{toolbar}</div> : null}
      <AdminTable
        rowKey="_id"
        loading={loading}
        dataSource={items}
        size="middle"
        locale={{
          emptyText: <EmptyState height={160}>暂无数据</EmptyState>,
        }}
        paginationBind={pagination}
        columns={actionColumn ? [...columns, actionColumn] : columns}
      />
      {editForm && EditForm && values && (
      <AdminModal
        title={editing ? editForm.modalTitle({ id: editing.id, isNew: !editing.id }) : ''}
        open={editing !== null}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
        width={editForm.width ?? 520}
      >
        {formError && <Alert type="error" showIcon message={formError} style={{ marginBottom: 16 }} />}
        <EditForm values={values} onChange={(patch) => setValues((cur) => (cur ? { ...cur, ...patch } : cur))} />
      </AdminModal>
      )}
    </>
  );

  if (embedded) {
    return <div className="admin-table-embedded">{table}</div>;
  }

  return (
    <TablePage extra={extra} subtitle={subtitle} toolbar={toolbar}>
      {table}
    </TablePage>
  );
}
