import { useRef, useState } from 'react';
import { Alert, Button, Image, Input, Modal, Space, message } from 'antd';
import { api } from '../api';
import CrudTable from '../components/CrudTable';
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
      <div style={{ padding: '16px 24px 0' }}>
        <Alert
          type="info"
          showIcon
          message="勋章的达成条件写在 App 代码里，这里只能改展示文案和图标；新增勋章需要发版。"
        />
      </div>
      <CrudTable
        col="achv_defs"
        refreshRef={refresh}
        pageSize={50}
        showActions={false}
        columns={[
          { title: 'slug', dataIndex: 'slug', width: 130, render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
          {
            title: '图标',
            dataIndex: 'icon',
            width: 80,
            render: (v: string) =>
              v ? <Image src={v} width={40} height={40} style={{ objectFit: 'cover' }} /> : '—',
          },
          { title: '名称', dataIndex: 'name', width: 140 },
          { title: '描述', dataIndex: 'desc' },
          {
            title: '操作',
            width: 90,
            render: (_: unknown, row: AchvDef) => (
              <Button size="small" onClick={() => setEditing(row)}>
                编辑
              </Button>
            ),
          },
        ]}
      />
      <Modal
        title={`编辑勋章（${editing?.slug ?? ''}）`}
        open={editing !== null}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
      >
        <Space direction="vertical" style={{ width: '100%' }}>
          <div>名称：</div>
          <Input value={editing?.name ?? ''} onChange={(e) => setEditing((c) => (c ? { ...c, name: e.target.value } : c))} />
          <div>描述：</div>
          <Input value={editing?.desc ?? ''} onChange={(e) => setEditing((c) => (c ? { ...c, desc: e.target.value } : c))} />
          <div>图标：</div>
          <Space>
            {editing?.icon && <Image src={editing.icon} width={48} height={48} style={{ objectFit: 'cover' }} />}
            <ImgUpload text="上传图标" onDone={(url) => setEditing((c) => (c ? { ...c, icon: url } : c))} />
          </Space>
        </Space>
      </Modal>
    </>
  );
}
