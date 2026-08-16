import { useRef, useState } from 'react';
import { Button, Input, Space, Switch, Tabs, message } from 'antd';
import { api } from '../api';
import { FormField, FormSection } from '../components/AdminForm';
import AdminModal from '../components/AdminModal';
import CloudImage from '../components/CloudImage';
import CrudTable from '../components/CrudTable';
import { ActionBtn, TableActions } from '../components/TableActions';
import ImgUpload, { CROP_PRESETS } from '../components/ImgUpload';

interface ImgRow {
  _id: string;
  url?: string;
  slogan?: string;
  sort?: number;
  enabled?: boolean;
}

const TABLES = [
  { col: 'poster_task', label: '任务海报' },
  { col: 'poster_wish', label: '心愿海报' },
  { col: 'poster_done', label: '实现海报' },
  { col: 'hero_images', label: '首页大图' },
  { col: 'cover_declare', label: '宣告卡封面' },
  { col: 'cover_done', label: '凭证卡封面' },
];

/** 单张图片素材表：缩略图 + 标语 + 排序 + 启停 + 换图/上传 */
function ImgTable({ col }: { col: string }) {
  const uploadPreset = col === 'hero_images' || col.startsWith('cover_') ? 'hero' : 'poster';
  const cropHint = CROP_PRESETS[uploadPreset].hint;
  const refresh = useRef<(() => void) | null>(null);
  const [editing, setEditing] = useState<{ id: string; url: string; slogan: string; sort: number } | null>(null);
  const [saving, setSaving] = useState(false);

  async function setEnabled(row: ImgRow, enabled: boolean) {
    try {
      await api.post(`/admin/content/${col}`, { id: row._id, doc: { enabled } });
      refresh.current?.();
    } catch (e: any) {
      message.error(`操作失败：${e.message}`);
    }
  }

  async function save() {
    if (!editing) return;
    setSaving(true);
    try {
      await api.post(`/admin/content/${col}`, {
        id: editing.id || undefined,
        doc: {
          url: editing.url,
          slogan: editing.slogan,
          sort: editing.sort,
          ...(editing.id ? {} : { enabled: true }),
        },
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
        col={col}
        refreshRef={refresh}
        filters={
          <Button
            type="primary"
            onClick={() => setEditing({ id: '', url: '', slogan: '', sort: 999 })}
          >
            新建素材
          </Button>
        }
        columns={[
          {
            title: '图',
            dataIndex: 'url',
            width: 90,
            render: (v: string) =>
              v ? (
                <CloudImage
                  url={v}
                  width={64}
                  height={64}
                  style={{ objectFit: 'cover', borderRadius: 6 }}
                />
              ) : (
                <span style={{ color: '#ccc', fontSize: 12 }}>待上传</span>
              ),
          },
          {
            title: '标语',
            dataIndex: 'slogan',
            render: (v: string) => <span style={{ whiteSpace: 'pre-wrap' }}>{v || '—'}</span>,
          },
          { title: '排序', dataIndex: 'sort', width: 70 },
          {
            title: '启用',
            dataIndex: 'enabled',
            width: 80,
            render: (v: boolean | undefined, row: ImgRow) => (
              <Switch size="small" checked={v !== false} onChange={(c) => setEnabled(row, c)} />
            ),
          },
          {
            title: '操作',
            width: 88,
            render: (_: unknown, row: ImgRow) => (
              <TableActions>
                <ActionBtn
                  variant="primary"
                  onClick={() =>
                    setEditing({
                      id: row._id,
                      url: row.url ?? '',
                      slogan: row.slogan ?? '',
                      sort: row.sort ?? 0,
                    })
                  }
                >
                  编辑
                </ActionBtn>
              </TableActions>
            ),
          },
        ]}
      />
      <AdminModal
        title={editing?.id ? '编辑素材' : '新建素材'}
        open={editing !== null}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
        width={560}
      >
        <FormSection title="预览">
          {editing?.url ? (
            <CloudImage url={editing.url} width={120} height={120} style={{ objectFit: 'cover', borderRadius: 10 }} />
          ) : (
            <span style={{ color: '#a2a4ae', fontSize: 13 }}>还没有图片</span>
          )}
        </FormSection>
        <FormSection title="图片" desc={cropHint}>
          <Space wrap>
            <ImgUpload preset={uploadPreset} onDone={(url) => setEditing((c) => (c ? { ...c, url } : c))} />
            <Input
              placeholder="或直接粘贴图片 URL"
              style={{ width: 280 }}
              value={editing?.url ?? ''}
              onChange={(e) => setEditing((c) => (c ? { ...c, url: e.target.value } : c))}
            />
          </Space>
        </FormSection>
        <FormField label="标语" hint="支持 \\n 换行">
          <Input.TextArea
            rows={3}
            value={editing?.slogan ?? ''}
            onChange={(e) => setEditing((c) => (c ? { ...c, slogan: e.target.value } : c))}
          />
        </FormField>
        <FormField label="排序">
          <Input type="number" style={{ width: 120 }} value={editing?.sort ?? 0} onChange={(e) => setEditing((c) => (c ? { ...c, sort: Number(e.target.value) || 0 } : c))} />
        </FormField>
      </AdminModal>
    </>
  );
}

export default function Images() {
  return (
    <Tabs
      className="admin-table-tabs"
      items={TABLES.map((t) => ({ key: t.col, label: t.label, children: <ImgTable col={t.col} /> }))}
    />
  );
}
