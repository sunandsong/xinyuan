import { useEffect, useState } from 'react';
import {
  Button,
  Card,
  DatePicker,
  Input,
  Modal,
  Popconfirm,
  Space,
  Switch,
  Table,
  Tag,
  message,
} from 'antd';
import dayjs, { type Dayjs } from 'dayjs';
import { api } from '../api';
import { fmtTime, usePagedList } from '../paged';

/** announcements 集合里存最低版本号的特殊文档 id（跟后端 config.ts 约定一致） */
const MIN_VERSION_ID = 'sys_min_version';

interface Ann {
  _id: string;
  title?: string;
  body?: string;
  startAt?: number;
  endAt?: number;
  enabled?: boolean;
}

interface Editing {
  id: string;
  title: string;
  body: string;
  range: [Dayjs, Dayjs] | null;
  enabled: boolean;
}

export default function Announcements() {
  const { items, total, page, setPage, loading, reload } = usePagedList<Ann>(
    '/admin/content/announcements',
    20,
    {},
  );
  const list = items.filter((a) => a._id !== MIN_VERSION_ID);

  const [editing, setEditing] = useState<Editing | null>(null);
  const [saving, setSaving] = useState(false);

  // 强更版本卡
  const [minVersion, setMinVersion] = useState('');
  const [mvLoaded, setMvLoaded] = useState(false);
  const [mvSaving, setMvSaving] = useState(false);

  useEffect(() => {
    api
      .get(`/admin/content/announcements?f__id=${MIN_VERSION_ID}`)
      .then((d) => setMinVersion(String(d.items[0]?.value ?? '')))
      .catch(() => {})
      .finally(() => setMvLoaded(true));
  }, []);

  async function saveMinVersion() {
    setMvSaving(true);
    try {
      await api.post('/admin/content/announcements', {
        id: MIN_VERSION_ID,
        doc: { value: minVersion.trim(), enabled: false }, // enabled:false 免得被当公告下发
      });
      message.success('最低版本已保存');
    } catch (e: any) {
      message.error(`保存失败：${e.message}`);
    } finally {
      setMvSaving(false);
    }
  }

  async function save() {
    if (!editing) return;
    if (!editing.title.trim()) {
      message.warning('标题不能为空');
      return;
    }
    setSaving(true);
    try {
      await api.post('/admin/content/announcements', {
        id: editing.id || undefined,
        doc: {
          title: editing.title.trim(),
          body: editing.body,
          // 时间范围写毫秒时间戳（App 端按 startAt <= now <= endAt 生效）
          startAt: editing.range ? editing.range[0].valueOf() : null,
          endAt: editing.range ? editing.range[1].valueOf() : null,
          enabled: editing.enabled,
        },
      });
      message.success('已保存');
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
      await api.post('/admin/content/announcements/delete', { id });
      message.success('已删除');
      reload();
    } catch (e: any) {
      message.error(`删除失败：${e.message}`);
    }
  }

  const now = Date.now();

  return (
    <div style={{ padding: 24 }}>
      <Card size="small" title="强更版本" style={{ marginBottom: 16 }}>
        <Space>
          <Input
            placeholder="如 1.2.0（低于此版本的 App 提示强制更新）"
            style={{ width: 320 }}
            value={minVersion}
            disabled={!mvLoaded}
            onChange={(e) => setMinVersion(e.target.value)}
          />
          <Button type="primary" loading={mvSaving} onClick={saveMinVersion}>
            保存
          </Button>
          <span style={{ color: '#999', fontSize: 12 }}>留空 = 不强更</span>
        </Space>
      </Card>

      <Space style={{ marginBottom: 16 }}>
        <Button
          type="primary"
          onClick={() => setEditing({ id: '', title: '', body: '', range: null, enabled: true })}
        >
          发公告
        </Button>
      </Space>
      <Table<Ann>
        rowKey="_id"
        loading={loading}
        dataSource={list}
        pagination={{
          current: page,
          pageSize: 20,
          total,
          showSizeChanger: false,
          onChange: setPage,
        }}
        columns={[
          { title: '标题', dataIndex: 'title' },
          { title: '内容', dataIndex: 'body', render: (v) => <span style={{ whiteSpace: 'pre-wrap' }}>{v}</span> },
          { title: '开始', dataIndex: 'startAt', width: 150, render: (v) => fmtTime(v) },
          { title: '结束', dataIndex: 'endAt', width: 150, render: (v) => fmtTime(v) },
          {
            title: '状态',
            width: 90,
            render: (_, a) => {
              if (a.enabled === false) return <Tag>停用</Tag>;
              const started = (a.startAt ?? -Infinity) <= now;
              const ended = now > (a.endAt ?? Infinity);
              if (!started) return <Tag color="blue">未开始</Tag>;
              if (ended) return <Tag>已结束</Tag>;
              return <Tag color="green">生效中</Tag>;
            },
          },
          {
            title: '操作',
            width: 130,
            render: (_, a) => (
              <Space>
                <Button
                  size="small"
                  onClick={() =>
                    setEditing({
                      id: a._id,
                      title: a.title ?? '',
                      body: a.body ?? '',
                      range: a.startAt && a.endAt ? [dayjs(a.startAt), dayjs(a.endAt)] : null,
                      enabled: a.enabled !== false,
                    })
                  }
                >
                  编辑
                </Button>
                <Popconfirm title="删除这条公告？" onConfirm={() => remove(a._id)}>
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
        title={editing?.id ? '编辑公告' : '发公告'}
        open={editing !== null}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
      >
        <Space direction="vertical" style={{ width: '100%' }}>
          <div>标题：</div>
          <Input
            value={editing?.title ?? ''}
            onChange={(e) => setEditing((c) => (c ? { ...c, title: e.target.value } : c))}
          />
          <div>内容：</div>
          <Input.TextArea
            rows={4}
            value={editing?.body ?? ''}
            onChange={(e) => setEditing((c) => (c ? { ...c, body: e.target.value } : c))}
          />
          <div>生效时间范围（不填 = 一直生效）：</div>
          <DatePicker.RangePicker
            showTime
            value={editing?.range ?? null}
            onChange={(v) =>
              setEditing((c) => (c ? { ...c, range: v && v[0] && v[1] ? [v[0], v[1]] : null } : c))
            }
          />
          <Space>
            <span>启用：</span>
            <Switch
              checked={editing?.enabled ?? true}
              onChange={(v) => setEditing((c) => (c ? { ...c, enabled: v } : c))}
            />
          </Space>
        </Space>
      </Modal>
    </div>
  );
}
