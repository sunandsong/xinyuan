import { useCallback, useEffect, useState } from 'react';
import {
  Button,
  Checkbox,
  Descriptions,
  Drawer,
  Input,
  Modal,
  Popconfirm,
  Select,
  Space,
  Spin,
  Table,
  Tag,
  Typography,
  message,
} from 'antd';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';

const PAGE_SIZE = 20; // 跟后端 /admin/users 的分页一致

interface UserRow {
  _id: string;
  account?: string;
  nickname?: string;
  avatarUrl?: string | null;
  gender?: string | null;
  birthday?: string | null;
  achievements?: Record<string, number>;
  checkins?: Record<string, number>;
  doneCount?: number;
  taskCount?: number;
  achvCount?: number;
  placeCount?: number;
  createdAt: number;
  lastActiveAt?: number;
  lastLoginAt?: number;
  banned?: boolean;
  wishTotal: number;
  wishDone: number;
}

interface DetailData {
  user: UserRow;
  counts: { wishes: number; tasks: number; letters: number };
  recentLogins: Array<{ at: number; device?: string; os?: string; appVersion?: string; ip?: string }>;
}

interface AchvDef {
  slug: string;
  name: string;
}

const AVATAR_COLORS = ['#5B8DEF', '#E0A64B', '#E0708A', '#4FB88A', '#A080E0'];

function fmtTime(ts?: number): string {
  if (!ts) return '—';
  const d = new Date(ts);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}.${p(d.getMonth() + 1)}.${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** 头像：有图显图（加载失败回退），无图昵称首字彩圆 */
function AvatarCell({ url, name }: { url?: string | null; name?: string }) {
  const [broken, setBroken] = useState(false);
  const n = name || '?';
  const color = AVATAR_COLORS[Math.abs([...n].reduce((h, c) => h * 31 + c.charCodeAt(0), 0)) % AVATAR_COLORS.length];
  if (url && !broken) {
    return (
      <img
        src={url}
        onError={() => setBroken(true)}
        style={{ width: 32, height: 32, borderRadius: '50%', objectFit: 'cover' }}
      />
    );
  }
  return (
    <div
      style={{
        width: 32,
        height: 32,
        borderRadius: '50%',
        background: color,
        color: '#fff',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontWeight: 600,
      }}
    >
      {n.slice(0, 1)}
    </div>
  );
}

export default function Users() {
  const navigate = useNavigate();
  const [rows, setRows] = useState<UserRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [q, setQ] = useState('');
  const [sort, setSort] = useState('lastActiveAt');
  const [loading, setLoading] = useState(false);

  // 详情抽屉
  const [detailUid, setDetailUid] = useState<string | null>(null);
  const [detail, setDetail] = useState<DetailData | null>(null);
  const [achvDefs, setAchvDefs] = useState<AchvDef[]>([]);

  // 补发弹窗
  const [grantOpen, setGrantOpen] = useState(false);
  const [grantAchvs, setGrantAchvs] = useState<string[]>([]);
  const [grantSpots, setGrantSpots] = useState<string[]>([]);
  const [grantSaving, setGrantSaving] = useState(false);

  const load = useCallback(
    (p = page, kw = q, s = sort) => {
      setLoading(true);
      api
        .get(`/admin/users?q=${encodeURIComponent(kw)}&sort=${s}&skip=${(p - 1) * PAGE_SIZE}`)
        .then((d) => {
          setRows(d.items);
          setTotal(d.total);
        })
        .catch((e) => message.error(`加载失败：${e.message}`))
        .finally(() => setLoading(false));
    },
    [page, q, sort],
  );

  useEffect(() => {
    load(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function openDetail(uid: string) {
    setDetailUid(uid);
    setDetail(null);
    api
      .get(`/admin/users/${uid}`)
      .then(setDetail)
      .catch((e) => {
        message.error(`详情加载失败：${e.message}`);
        setDetailUid(null);
      });
    if (achvDefs.length === 0) {
      api
        .get('/admin/content/achv_defs?limit=100')
        .then((d) => setAchvDefs(d.items))
        .catch(() => {});
    }
  }

  function refreshDetail(uid: string) {
    api.get(`/admin/users/${uid}`).then(setDetail).catch(() => {});
    load();
  }

  async function handleResetPassword(uid: string) {
    try {
      const { password } = await api.post(`/admin/users/${uid}/reset-password`);
      Modal.success({
        title: '密码已重置',
        content: (
          <Space direction="vertical">
            <span>
              新密码（只显示这一次，请立即复制给用户）：
            </span>
            <Typography.Text code copyable style={{ fontSize: 18 }}>
              {password}
            </Typography.Text>
          </Space>
        ),
      });
    } catch (e: any) {
      message.error(`重置失败：${e.message}`);
    }
  }

  async function handleBan(uid: string, banned: boolean) {
    try {
      await api.post(`/admin/users/${uid}/ban`, { banned });
      message.success(banned ? '已封禁' : '已解封');
      refreshDetail(uid);
    } catch (e: any) {
      message.error(`操作失败：${e.message}`);
    }
  }

  async function handleDelete(uid: string) {
    try {
      await api.post(`/admin/users/${uid}/delete`);
      message.success('已删号（软删，同步数据一并标删）');
      setDetailUid(null);
      load();
    } catch (e: any) {
      message.error(`删号失败：${e.message}`);
    }
  }

  async function handleResetProfile(uid: string, what: { nickname?: true; avatar?: true }) {
    try {
      await api.post(`/admin/users/${uid}/reset-profile`, what);
      message.success('已重置');
      refreshDetail(uid);
    } catch (e: any) {
      message.error(`重置失败：${e.message}`);
    }
  }

  async function handleGrant() {
    if (!detailUid) return;
    const body: Record<string, unknown> = {};
    if (grantAchvs.length) body.achievements = Object.fromEntries(grantAchvs.map((s) => [s, 0]));
    if (grantSpots.length) body.checkins = Object.fromEntries(grantSpots.map((s) => [s, 0]));
    if (!Object.keys(body).length) {
      message.warning('没选要补发的内容');
      return;
    }
    setGrantSaving(true);
    try {
      await api.post(`/admin/users/${detailUid}/grant`, body);
      message.success('已补发');
      setGrantOpen(false);
      setGrantAchvs([]);
      setGrantSpots([]);
      refreshDetail(detailUid);
    } catch (e: any) {
      message.error(`补发失败：${e.message}`);
    } finally {
      setGrantSaving(false);
    }
  }

  const achvName = (slug: string) => achvDefs.find((a) => a.slug === slug)?.name ?? slug;
  const u = detail?.user;

  return (
    <div style={{ padding: 24 }}>
      <Space style={{ marginBottom: 16 }}>
        <Input.Search
          placeholder="搜账号 / 昵称"
          allowClear
          style={{ width: 260 }}
          onSearch={(v) => {
            setQ(v);
            setPage(1);
            load(1, v, sort);
          }}
        />
        <Select
          value={sort}
          style={{ width: 160 }}
          onChange={(v) => {
            setSort(v);
            setPage(1);
            load(1, q, v);
          }}
          options={[
            { value: 'lastActiveAt', label: '按最后活跃' },
            { value: 'createdAt', label: '按注册时间' },
            { value: 'doneCount', label: '按实现心愿数' },
          ]}
        />
      </Space>
      <Table<UserRow>
        rowKey="_id"
        loading={loading}
        dataSource={rows}
        pagination={{
          current: page,
          pageSize: PAGE_SIZE,
          total,
          showSizeChanger: false,
          showTotal: (t) => `共 ${t} 人`,
          onChange: (p) => {
            setPage(p);
            load(p);
          },
        }}
        columns={[
          {
            title: '用户',
            render: (_, r) => (
              <Space>
                <AvatarCell url={r.avatarUrl} name={r.nickname} />
                <span>
                  <div>{r.nickname || '—'}</div>
                  <div style={{ color: '#999', fontSize: 12 }}>{r.account}</div>
                </span>
              </Space>
            ),
          },
          { title: '心愿', render: (_, r) => `${r.wishDone}/${r.wishTotal}` },
          { title: '任务', dataIndex: 'taskCount', render: (v) => v ?? 0 },
          { title: '奖杯', dataIndex: 'achvCount', render: (v) => v ?? 0 },
          { title: '足迹', dataIndex: 'placeCount', render: (v) => v ?? 0 },
          { title: '最后活跃', dataIndex: 'lastActiveAt', render: fmtTime },
          { title: '注册时间', dataIndex: 'createdAt', render: fmtTime },
          {
            title: '状态',
            render: (_, r) => (r.banned ? <Tag color="red">已封禁</Tag> : <Tag color="green">正常</Tag>),
          },
          {
            title: '操作',
            render: (_, r) => <a onClick={() => openDetail(r._id)}>详情</a>,
          },
        ]}
      />

      <Drawer
        title={u ? `${u.nickname || u.account || detailUid}` : '用户详情'}
        width={560}
        open={detailUid !== null}
        onClose={() => setDetailUid(null)}
      >
        {!detail || !u ? (
          <div style={{ textAlign: 'center', padding: 48 }}>
            <Spin />
          </div>
        ) : (
          <Space direction="vertical" size="large" style={{ width: '100%' }}>
            <Space align="center">
              <AvatarCell url={u.avatarUrl} name={u.nickname} />
              <div>
                <div style={{ fontWeight: 600 }}>{u.nickname || '—'}</div>
                <div style={{ color: '#999', fontSize: 12 }}>{u._id}</div>
              </div>
              {u.banned && <Tag color="red">已封禁</Tag>}
            </Space>

            <Descriptions
              size="small"
              column={2}
              items={[
                { key: 'account', label: '账号', children: u.account ?? '—' },
                { key: 'gender', label: '性别', children: u.gender ?? '—' },
                { key: 'birthday', label: '生日', children: u.birthday ?? '—' },
                { key: 'createdAt', label: '注册', children: fmtTime(u.createdAt) },
                { key: 'lastActive', label: '最后活跃', children: fmtTime(u.lastActiveAt) },
                { key: 'lastLogin', label: '最后登录', children: fmtTime(u.lastLoginAt) },
                {
                  key: 'counts',
                  label: '数据量',
                  children: `心愿 ${detail.counts.wishes} · 任务 ${detail.counts.tasks} · 胶囊 ${detail.counts.letters}`,
                  span: 2,
                },
              ]}
            />

            <Space wrap>
              <Button size="small" onClick={() => navigate(`/wishes?uid=${u._id}`)}>
                看 ta 的心愿
              </Button>
              <Button size="small" onClick={() => navigate(`/tasks?uid=${u._id}`)}>
                看 ta 的任务
              </Button>
              <Button size="small" onClick={() => navigate(`/capsules?uid=${u._id}`)}>
                看 ta 的胶囊
              </Button>
            </Space>

            <div>
              <Space style={{ marginBottom: 8 }}>
                <b>荣誉 & 足迹</b>
                <Button size="small" onClick={() => setGrantOpen(true)}>
                  补发
                </Button>
              </Space>
              <div>
                {Object.keys(u.achievements ?? {}).map((slug) => (
                  <Tag key={slug} color="gold">
                    {achvName(slug)}
                  </Tag>
                ))}
                {Object.keys(u.checkins ?? {}).map((place) => (
                  <Tag key={place} color="blue">
                    {place}
                  </Tag>
                ))}
                {!Object.keys(u.achievements ?? {}).length && !Object.keys(u.checkins ?? {}).length && (
                  <span style={{ color: '#999' }}>还没有</span>
                )}
              </div>
            </div>

            <div>
              <b>最近登录（{detail.recentLogins.length}）</b>
              {detail.recentLogins.length === 0 ? (
                <div style={{ color: '#999', marginTop: 8 }}>无登录记录</div>
              ) : (
                <Table
                  size="small"
                  rowKey={(r) => String(r.at)}
                  dataSource={detail.recentLogins}
                  pagination={false}
                  style={{ marginTop: 8 }}
                  columns={[
                    { title: '时间', dataIndex: 'at', render: fmtTime },
                    { title: '设备', dataIndex: 'device', render: (v) => v ?? '—' },
                    { title: '系统', dataIndex: 'os', render: (v) => v ?? '—' },
                    { title: '版本', dataIndex: 'appVersion', render: (v) => v ?? '—' },
                    { title: 'IP', dataIndex: 'ip', render: (v) => v ?? '—' },
                  ]}
                />
              )}
            </div>

            <div>
              <b>管理操作</b>
              <div style={{ marginTop: 8 }}>
                <Space wrap>
                  <Popconfirm title="生成随机新密码并立刻生效？" onConfirm={() => handleResetPassword(u._id)}>
                    <Button size="small">重置密码</Button>
                  </Popconfirm>
                  <Popconfirm title="把昵称重置成默认昵称？" onConfirm={() => handleResetProfile(u._id, { nickname: true })}>
                    <Button size="small">重置昵称</Button>
                  </Popconfirm>
                  <Popconfirm title="清空头像？" onConfirm={() => handleResetProfile(u._id, { avatar: true })}>
                    <Button size="small">清空头像</Button>
                  </Popconfirm>
                  {u.banned ? (
                    <Popconfirm title="解除封禁？" onConfirm={() => handleBan(u._id, false)}>
                      <Button size="small">解封</Button>
                    </Popconfirm>
                  ) : (
                    <Popconfirm title="封禁后该用户无法登录和同步" onConfirm={() => handleBan(u._id, true)}>
                      <Button size="small" danger>
                        封禁
                      </Button>
                    </Popconfirm>
                  )}
                  <Popconfirm
                    title="删号（软删）？"
                    description="用户与其心愿/任务/胶囊全部标删，账号名释放"
                    onConfirm={() => handleDelete(u._id)}
                  >
                    <Button size="small" danger>
                      删号
                    </Button>
                  </Popconfirm>
                </Space>
              </div>
            </div>
          </Space>
        )}
      </Drawer>

      <Modal
        title="补发荣誉 / 足迹"
        open={grantOpen}
        onCancel={() => setGrantOpen(false)}
        onOk={handleGrant}
        confirmLoading={grantSaving}
        okText="补发"
      >
        <div style={{ marginBottom: 8 }}>勋章（已拥有的不在列）：</div>
        <Checkbox.Group
          value={grantAchvs}
          onChange={(v) => setGrantAchvs(v as string[])}
          options={achvDefs
            .filter((a) => !(u?.achievements ?? {})[a.slug])
            .map((a) => ({ label: a.name, value: a.slug }))}
        />
        <div style={{ margin: '16px 0 8px' }}>景点打卡（输入景点名回车，可多个）：</div>
        <Select
          mode="tags"
          style={{ width: '100%' }}
          placeholder="如：故宫"
          value={grantSpots}
          onChange={setGrantSpots}
          open={false}
        />
      </Modal>
    </div>
  );
}
