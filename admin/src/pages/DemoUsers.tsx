import { useCallback, useEffect, useState } from 'react';
import {
  Button,
  Checkbox,
  Input,
  Modal,
  Popconfirm,
  Select,
  Space,
  Spin,
  Table,
  Tag,
  message,
} from 'antd';
import { api } from '../api';
import ImgUpload from '../components/ImgUpload';
import { fmtTime } from '../paged';

interface DemoUser {
  _id: string;
  nickname?: string;
  gender?: string | null;
  avatarUrl?: string | null;
  taskCount?: number;
  doneCount?: number;
  achvCount?: number;
  placeCount?: number;
  achievements?: Record<string, number>;
  checkins?: Record<string, number>;
  updatedAt?: number;
}

interface AchvDef {
  slug: string;
  name: string;
}

interface Editing {
  id: string; // 空串 = 新建
  nickname: string;
  gender: string;
  avatarUrl: string;
  taskCount: number;
  achievements: string[];
  doneWishTitles: string[];
  checkins: string[];
}

/** 演示用户：管理端造的假账号（无账号密码登录不了），排行榜/热度榜的门面数据。
 * 编辑是全量回填语义——后端按这份完整描述 diff 落库，漏填的字段等于删掉。 */
export default function DemoUsers() {
  const [rows, setRows] = useState<DemoUser[] | null>(null);
  const [achvDefs, setAchvDefs] = useState<AchvDef[]>([]);
  const [editing, setEditing] = useState<Editing | null>(null);
  const [editLoading, setEditLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [markOpen, setMarkOpen] = useState(false);
  const [markText, setMarkText] = useState('');
  const [marking, setMarking] = useState(false);

  const load = useCallback(() => {
    api
      .get('/admin/demo-users')
      .then((d) => setRows(d.items))
      .catch((e) => message.error(`加载失败：${e.message}`));
  }, []);

  useEffect(() => {
    load();
    api
      .get('/admin/content/achv_defs?limit=100')
      .then((d) => setAchvDefs(d.items))
      .catch(() => {});
  }, [load]);

  /** 编辑打开：全量回填。doneWishTitles 不在 user 文档上，得查该 uid 的未删心愿 */
  async function openEdit(row?: DemoUser) {
    if (!row) {
      setEditing({
        id: '',
        nickname: '',
        gender: '',
        avatarUrl: '',
        taskCount: 0,
        achievements: [],
        doneWishTitles: [],
        checkins: [],
      });
      return;
    }
    setEditLoading(true);
    setEditing({
      id: row._id,
      nickname: row.nickname ?? '',
      gender: row.gender ?? '',
      avatarUrl: row.avatarUrl ?? '',
      taskCount: row.taskCount ?? 0,
      achievements: Object.keys(row.achievements ?? {}),
      doneWishTitles: [],
      checkins: Object.keys(row.checkins ?? {}),
    });
    try {
      const d = await api.get(`/admin/content/wishes?f_uid=${row._id}&f_deleted=false&limit=100`);
      setEditing((c) =>
        c && c.id === row._id ? { ...c, doneWishTitles: d.items.map((w: any) => String(w.title)) } : c,
      );
    } catch (e: any) {
      message.error(`拉取该用户心愿失败：${e.message}（继续编辑会清空其心愿，请先关掉重试）`);
    } finally {
      setEditLoading(false);
    }
  }

  async function save() {
    if (!editing) return;
    if (!editing.nickname.trim()) {
      message.warning('昵称不能为空');
      return;
    }
    setSaving(true);
    try {
      await api.post('/admin/demo-users', {
        ...(editing.id ? { id: editing.id } : {}),
        nickname: editing.nickname.trim(),
        gender: editing.gender || null,
        avatarUrl: editing.avatarUrl || null,
        taskCount: editing.taskCount,
        achievements: editing.achievements,
        doneWishTitles: editing.doneWishTitles,
        checkins: editing.checkins,
      });
      message.success('已保存');
      setEditing(null);
      load();
    } catch (e: any) {
      message.error(`保存失败：${e.message}`);
    } finally {
      setSaving(false);
    }
  }

  async function remove(uid: string) {
    try {
      await api.post(`/admin/demo-users/${uid}/delete`);
      message.success('已删除（含其全部心愿）');
      load();
    } catch (e: any) {
      message.error(`删除失败：${e.message}`);
    }
  }

  async function runMark() {
    const uids = markText
      .split(/[\s,，、]+/)
      .map((s) => s.trim())
      .filter(Boolean);
    if (uids.length === 0) {
      message.warning('填入要打标的 uid');
      return;
    }
    setMarking(true);
    try {
      const d = await api.post('/admin/demo-users/mark', { uids });
      message.success(`已给 ${d.marked} 个账号打上演示标记`);
      setMarkOpen(false);
      setMarkText('');
      load();
    } catch (e: any) {
      message.error(`打标失败：${e.message}`);
    } finally {
      setMarking(false);
    }
  }

  return (
    <div style={{ padding: 24 }}>
      <Space style={{ marginBottom: 16 }}>
        <Button type="primary" onClick={() => openEdit()}>
          新建演示用户
        </Button>
        <Button onClick={() => setMarkOpen(true)}>批量打演示标记</Button>
      </Space>
      {rows === null ? (
        <div style={{ textAlign: 'center', padding: 48 }}>
          <Spin />
        </div>
      ) : (
        <Table<DemoUser>
          rowKey="_id"
          dataSource={rows}
          pagination={false}
          columns={[
            { title: '昵称', dataIndex: 'nickname' },
            { title: 'uid', dataIndex: '_id', render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
            { title: '性别', dataIndex: 'gender', width: 70, render: (v) => v ?? '—' },
            { title: '心愿', dataIndex: 'doneCount', width: 70, render: (v) => v ?? 0 },
            { title: '任务', dataIndex: 'taskCount', width: 70, render: (v) => v ?? 0 },
            { title: '奖杯', dataIndex: 'achvCount', width: 70, render: (v) => v ?? 0 },
            { title: '足迹', dataIndex: 'placeCount', width: 70, render: (v) => v ?? 0 },
            { title: '更新', dataIndex: 'updatedAt', width: 150, render: (v) => fmtTime(v) },
            {
              title: '操作',
              width: 130,
              render: (_, row) => (
                <Space>
                  <Button size="small" onClick={() => openEdit(row)}>
                    编辑
                  </Button>
                  <Popconfirm title="硬删该演示用户及其全部心愿？" onConfirm={() => remove(row._id)}>
                    <Button size="small" danger>
                      删
                    </Button>
                  </Popconfirm>
                </Space>
              ),
            },
          ]}
        />
      )}

      <Modal
        title={editing?.id ? `编辑演示用户（${editing.id}）` : '新建演示用户'}
        open={editing !== null}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
        width={640}
      >
        {editLoading && (
          <div style={{ marginBottom: 8 }}>
            <Spin size="small" /> 正在回填已完成心愿…
          </div>
        )}
        <Space direction="vertical" style={{ width: '100%' }}>
          <Space wrap>
            <span>昵称：</span>
            <Input
              style={{ width: 180 }}
              value={editing?.nickname ?? ''}
              onChange={(e) => setEditing((c) => (c ? { ...c, nickname: e.target.value } : c))}
            />
            <span>性别：</span>
            <Select
              style={{ width: 90 }}
              value={editing?.gender ?? ''}
              onChange={(v) => setEditing((c) => (c ? { ...c, gender: v } : c))}
              options={[
                { value: '', label: '不设' },
                { value: '男', label: '男' },
                { value: '女', label: '女' },
              ]}
            />
            <span>任务数：</span>
            <Input
              type="number"
              style={{ width: 90 }}
              value={editing?.taskCount ?? 0}
              onChange={(e) =>
                setEditing((c) => (c ? { ...c, taskCount: Math.max(0, Number(e.target.value) || 0) } : c))
              }
            />
          </Space>
          <Space>
            <span>头像：</span>
            <Input
              placeholder="URL 手填"
              style={{ width: 320 }}
              value={editing?.avatarUrl ?? ''}
              onChange={(e) => setEditing((c) => (c ? { ...c, avatarUrl: e.target.value } : c))}
            />
            <ImgUpload text="上传" onDone={(url) => setEditing((c) => (c ? { ...c, avatarUrl: url } : c))} />
          </Space>
          <div>
            勋章（勾上即拥有）：
            <div style={{ marginTop: 4 }}>
              <Checkbox.Group
                value={editing?.achievements ?? []}
                onChange={(v) => setEditing((c) => (c ? { ...c, achievements: v as string[] } : c))}
                options={achvDefs.map((a) => ({ label: a.name, value: a.slug }))}
              />
            </div>
          </div>
          <div>已完成心愿（回车加一条，删掉即软删对应心愿）：</div>
          <Select
            mode="tags"
            style={{ width: '100%' }}
            placeholder="如：去看一次海"
            value={editing?.doneWishTitles ?? []}
            onChange={(v) => setEditing((c) => (c ? { ...c, doneWishTitles: v } : c))}
            open={false}
          />
          <div>打卡景点（回车加一个）：</div>
          <Select
            mode="tags"
            style={{ width: '100%' }}
            placeholder="如：故宫"
            value={editing?.checkins ?? []}
            onChange={(v) => setEditing((c) => (c ? { ...c, checkins: v } : c))}
            open={false}
          />
          <Space>
            <span>计数自动推导：</span>
            <Tag>心愿 {editing?.doneWishTitles.length ?? 0}</Tag>
            <Tag>奖杯 {editing?.achievements.length ?? 0}</Tag>
            <Tag>足迹 {editing?.checkins.length ?? 0}</Tag>
          </Space>
        </Space>
      </Modal>

      <Modal
        title="批量打演示标记"
        open={markOpen}
        onCancel={() => setMarkOpen(false)}
        onOk={runMark}
        confirmLoading={marking}
        okText="打标"
      >
        <div style={{ marginBottom: 8, color: '#999' }}>
          把手工造进库里的假账号 uid 贴进来（空格/逗号/换行分隔），打上 isDemo 标记后，
          统计口径会把它们排除、并出现在本页列表里。
        </div>
        <Input.TextArea rows={6} value={markText} onChange={(e) => setMarkText(e.target.value)} />
      </Modal>
    </div>
  );
}
