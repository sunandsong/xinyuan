import { useRef, useState } from 'react';
import { Button, Image, Input, Modal, Space, Switch, Tabs, message } from 'antd';
import { api } from '../api';
import CrudTable from '../components/CrudTable';
import ImgUpload from '../components/ImgUpload';

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
];

/** 单张图片素材表：缩略图 + 标语 + 排序 + 启停 + 换图/上传 */
function ImgTable({ col }: { col: string }) {
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
        pageSize={50}
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
                <Image src={v} width={64} height={64} style={{ objectFit: 'cover', borderRadius: 6 }} />
              ) : (
                <span style={{ color: '#ccc' }}>无图</span>
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
            title: '素材',
            width: 90,
            render: (_: unknown, row: ImgRow) => (
              <Button
                size="small"
                onClick={() =>
                  setEditing({
                    id: row._id,
                    url: row.url ?? '',
                    slogan: row.slogan ?? '',
                    sort: row.sort ?? 0,
                  })
                }
              >
                编辑素材
              </Button>
            ),
          },
        ]}
      />
      <Modal
        title={editing?.id ? '编辑素材' : '新建素材'}
        open={editing !== null}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
      >
        <Space direction="vertical" style={{ width: '100%' }}>
          {editing?.url ? (
            <Image src={editing.url} width={120} height={120} style={{ objectFit: 'cover', borderRadius: 8 }} />
          ) : (
            <span style={{ color: '#999' }}>还没有图片</span>
          )}
          <Space>
            <ImgUpload onDone={(url) => setEditing((c) => (c ? { ...c, url } : c))} />
            <Input
              placeholder="或直接粘贴图片 URL"
              style={{ width: 280 }}
              value={editing?.url ?? ''}
              onChange={(e) => setEditing((c) => (c ? { ...c, url: e.target.value } : c))}
            />
          </Space>
          <div>标语（\n 换行）：</div>
          <Input.TextArea
            rows={3}
            value={editing?.slogan ?? ''}
            onChange={(e) => setEditing((c) => (c ? { ...c, slogan: e.target.value } : c))}
          />
          <div>排序：</div>
          <Input
            type="number"
            style={{ width: 120 }}
            value={editing?.sort ?? 0}
            onChange={(e) => setEditing((c) => (c ? { ...c, sort: Number(e.target.value) || 0 } : c))}
          />
        </Space>
      </Modal>
    </>
  );
}

export default function Images() {
  return (
    <Tabs
      style={{ padding: '0 24px' }}
      items={TABLES.map((t) => ({ key: t.col, label: t.label, children: <ImgTable col={t.col} /> }))}
    />
  );
}
