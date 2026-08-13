import { useRef, useState } from 'react';
import { Alert, Input, message } from 'antd';
import { api } from '../api';
import { FormField } from '../components/AdminForm';
import AdminModal from '../components/AdminModal';
import CloudImage from '../components/CloudImage';
import CrudTable from '../components/CrudTable';
import { ActionBtn, TableActions } from '../components/TableActions';
import ImgUpload from '../components/ImgUpload';

interface AchvDef {
  _id: string;
  slug: string;
  name: string;
  desc: string;
  icon?: string;
}

/** 荣誉定义（achv_defs）：只许改名字/描述/图标——达成判定逻辑写在 App 代码里，
 * slug 是判定的 key，这里新增/删除/改 slug 都不会生效，干脆不提供。 */
export default function Honors() {
  const refresh = useRef<(() => void) | null>(null);
  const [editing, setEditing] = useState<AchvDef | null>(null);
  const [saving, setSaving] = useState(false);

  async function save() {
    if (!editing) return;
    setSaving(true);
    try {
      await api.post('/admin/content/achv_defs', {
        id: editing._id,
        doc: { name: editing.name, desc: editing.desc, icon: editing.icon ?? '' },
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
        col="achv_defs"
        refreshRef={refresh}
        extra={
          <Alert
            type="info"
            showIcon
            style={{ borderRadius: 10, marginBottom: 16 }}
            message="勋章的达成条件写在 App 代码里，这里只能改展示文案和图标；新增勋章需要发版。"
          />
        }
        showActions={false}
        columns={[
          { title: 'slug', dataIndex: 'slug', width: 130, render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
          {
            title: '图标',
            dataIndex: 'icon',
            width: 80,
            render: (v: string) =>
              v ? (
                <CloudImage url={v} width={40} height={40} style={{ objectFit: 'cover' }} />
              ) : (
                <span style={{ color: '#ccc', fontSize: 12 }}>待上传</span>
              ),
          },
          { title: '名称', dataIndex: 'name', width: 140 },
          { title: '描述', dataIndex: 'desc' },
          {
            title: '操作',
            width: 88,
            render: (_: unknown, row: AchvDef) => (
              <TableActions>
                <ActionBtn variant="primary" onClick={() => setEditing(row)}>
                  编辑
                </ActionBtn>
              </TableActions>
            ),
          },
        ]}
      />
      <AdminModal
        title={`编辑勋章（${editing?.slug ?? ''}）`}
        open={editing !== null}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
        width={480}
      >
        <FormField label="名称" required>
          <Input value={editing?.name ?? ''} onChange={(e) => setEditing((c) => (c ? { ...c, name: e.target.value } : c))} />
        </FormField>
        <FormField label="描述">
          <Input value={editing?.desc ?? ''} onChange={(e) => setEditing((c) => (c ? { ...c, desc: e.target.value } : c))} />
        </FormField>
        <FormField label="图标" hint="建议 256×256 正方形">
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            {editing?.icon && (
              <CloudImage url={editing.icon} width={48} height={48} style={{ objectFit: 'cover', borderRadius: 10 }} />
            )}
            <ImgUpload text="上传图标" preset="icon" onDone={(url) => setEditing((c) => (c ? { ...c, icon: url } : c))} />
          </div>
        </FormField>
      </AdminModal>
    </>
  );
}
