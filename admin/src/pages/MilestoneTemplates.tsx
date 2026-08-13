import { useRef, useState } from 'react';
import { Button, Input, Popconfirm, Switch, Tag, message } from 'antd';
import { api } from '../api';
import { FormField } from '../components/AdminForm';
import AdminModal from '../components/AdminModal';
import { ActionBtn, TableActions } from '../components/TableActions';
import CrudTable from '../components/CrudTable';

interface StepTemplate {
  _id: string;
  title: string;
  steps: string[];
  sort?: number;
  enabled?: boolean;
}

/** 里程碑模板（preset_steps）：心愿标题 → 拆解步骤。
 * 编辑弹窗一行一步（回车分行），比裸 JSON 顺手。 */
export default function MilestoneTemplates() {
  const refresh = useRef<(() => void) | null>(null);
  const [editing, setEditing] = useState<{ id: string; title: string; steps: string } | null>(null);
  const [saving, setSaving] = useState(false);

  async function setEnabled(row: StepTemplate, enabled: boolean) {
    try {
      await api.post('/admin/content/preset_steps', { id: row._id, doc: { enabled } });
      refresh.current?.();
    } catch (e: any) {
      message.error(`操作失败：${e.message}`);
    }
  }

  async function remove(id: string) {
    try {
      await api.post('/admin/content/preset_steps/delete', { id });
      message.success('已删除');
      refresh.current?.();
    } catch (e: any) {
      message.error(`删除失败：${e.message}`);
    }
  }

  async function save() {
    if (!editing) return;
    const title = editing.title.trim();
    const steps = editing.steps
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean);
    if (!title || steps.length === 0) {
      message.warning('标题和步骤都不能为空');
      return;
    }
    setSaving(true);
    try {
      await api.post('/admin/content/preset_steps', {
        id: editing.id || undefined,
        doc: { title, steps, ...(editing.id ? {} : { sort: 999, enabled: true }) },
      });
      message.success('已保存');
      setEditing(null);
      refresh.current?.();
    } catch (e: any) {
      message.error(`保存失败：${e.message}`);
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <CrudTable
        col="preset_steps"
        refreshRef={refresh}
        showActions={false}
        filters={
          <Button type="primary" onClick={() => setEditing({ id: '', title: '', steps: '' })}>
            新建模板
          </Button>
        }
        columns={[
          { title: '心愿标题', dataIndex: 'title', width: 200 },
          {
            title: '步骤',
            dataIndex: 'steps',
            render: (steps: string[]) => (
              <>
                {(steps ?? []).map((s, i) => (
                  <Tag key={i}>{`${i + 1}. ${s}`}</Tag>
                ))}
              </>
            ),
          },
          {
            title: '启用',
            dataIndex: 'enabled',
            width: 80,
            render: (v: boolean | undefined, row: StepTemplate) => (
              <Switch size="small" checked={v !== false} onChange={(c) => setEnabled(row, c)} />
            ),
          },
          {
            title: '操作',
            width: 148,
            render: (_: unknown, row: StepTemplate) => (
              <TableActions>
                <ActionBtn
                  variant="primary"
                  onClick={() =>
                    setEditing({ id: row._id, title: row.title, steps: (row.steps ?? []).join('\n') })
                  }
                >
                  编辑
                </ActionBtn>
                <Popconfirm title="删除这套模板？" onConfirm={() => remove(row._id)}>
                  <ActionBtn variant="danger">删除</ActionBtn>
                </Popconfirm>
              </TableActions>
            ),
          },
        ]}
      />
      <AdminModal
        title={editing?.id ? '编辑模板' : '新建模板'}
        open={editing !== null}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
        width={560}
      >
        <FormField label="心愿标题" required hint="与用户输入的心愿标题匹配时推荐这套步骤">
          <Input
            value={editing?.title ?? ''}
            onChange={(e) => setEditing((c) => (c ? { ...c, title: e.target.value } : c))}
          />
        </FormField>
        <FormField label="步骤" hint="一行一步">
          <Input.TextArea
            rows={8}
            value={editing?.steps ?? ''}
            onChange={(e) => setEditing((c) => (c ? { ...c, steps: e.target.value } : c))}
          />
        </FormField>
      </AdminModal>
    </>
  );
}
