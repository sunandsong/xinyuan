import { useCallback, useEffect, useState } from 'react';
import {
  Button,
  Checkbox,
  Descriptions,
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
import { FormField, FormSection } from '../components/AdminForm';
import AdminModal from '../components/AdminModal';
import AdminTable from '../components/AdminTable';
import AvatarCell from '../components/AvatarCell';
import { ActionBtn, TableActions } from '../components/TableActions';
import TablePage from '../components/TablePage';
import { DEFAULT_TABLE_PAGE_SIZE } from '../tableConfig';

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

function fmtTime(ts?: number): string {
  if (!ts) return '—';
  const d = new Date(ts);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}.${p(d.getMonth() + 1)}.${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

export default function Users() {
  const navigate = useNavigate();
  const [rows, setRows] = useState<UserRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(DEFAULT_TABLE_PAGE_SIZE);
  const [q, setQ] = useState('');
  const [sort, setSort] = useState('lastActiveAt');
  const [loading, setLoading] = useState(false);

  // 详情弹窗
  const [detailUid, setDetailUid] = useState<string | null>(null);
  const [detail, setDetail] = useState<DetailData | null>(null);
  const [achvDefs, setAchvDefs] = useState<AchvDef[]>([]);

  // 补发弹窗
  const [grantOpen, setGrantOpen] = useState(false);
  const [grantAchvs, setGrantAchvs] = useState<string[]>([]);
  const [grantSpots, setGrantSpots] = useState<string[]>([]);
  const [grantSaving, setGrantSaving] = useState(false);

  const load = useCallback(
    (p = page, kw = q, s = sort, size = pageSize) => {
      setLoading(true);
      api
        .get(`/admin/users?q=${encodeURIComponent(kw)}&sort=${s}&skip=${(p - 1) * size}&limit=${size}`)
        .then((d) => {
          setRows(d.items);
          setTotal(d.total);
        })
        .catch((e) => message.error(`加载失败：${e.message}`))
        .finally(() => setLoading(false));
    },
    [page, q, sort, pageSize],
  );

  function onPageChange(p: number, size: number) {
    if (size !== pageSize) {
      setPageSize(size);
      setPage(1);
      load(1, q, sort, size);
      return;
    }
    setPage(p);
    load(p, q, sort, size);
  }

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
    <>
    <TablePage
      toolbar={
        <Space wrap>
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
          <span style={{ color: '#8A8C98', fontSize: 13 }}>共 {total} 人</span>
        </Space>
      }
    >
      <AdminTable<UserRow>
        rowKey="_id"
        loading={loading}
        dataSource={rows}
        size="middle"
        paginationBind={{ page, pageSize, total, onChange: onPageChange, unit: '人' }}
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
            width: 88,
            render: (_, r) => (
              <TableActions>
                <ActionBtn variant="primary" onClick={() => openDetail(r._id)}>
                  详情
                </ActionBtn>
              </TableActions>
            ),
          },
        ]}
      />
    </TablePage>

    <AdminModal
        title={u ? `用户 · ${u.nickname || u.account || detailUid}` : '用户详情'}
        width={640}
        open={detailUid !== null}
        onCancel={() => setDetailUid(null)}
        footer={
          <Button type="primary" onClick={() => setDetailUid(null)}>
            关闭
          </Button>
        }
      >
        {!detail || !u ? (
          <div style={{ textAlign: 'center', padding: 48 }}>
            <Spin />
          </div>
        ) : (
          <>
            <FormSection title="基本资料">
              <Space align="center" style={{ marginBottom: 16 }}>
                <AvatarCell url={u.avatarUrl} name={u.nickname} />
                <div>
                  <div style={{ fontWeight: 600 }}>{u.nickname || '—'}</div>
                  <div style={{ color: '#8a8c98', fontSize: 12 }}>{u._id}</div>
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
            </FormSection>

            <FormSection title="用户数据">
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
            </FormSection>

            <FormSection title="荣誉与足迹">
              <Space style={{ marginBottom: 8 }}>
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
                  <span style={{ color: '#8a8c98', fontSize: 13 }}>还没有</span>
                )}
              </div>
            </FormSection>

            <FormSection title="最近登录">
              {detail.recentLogins.length === 0 ? (
                <div style={{ color: '#8a8c98', fontSize: 13 }}>无登录记录</div>
              ) : (
                <Table
                  size="small"
                  rowKey={(r) => String(r.at)}
                  dataSource={detail.recentLogins}
                  pagination={false}
                  columns={[
                    { title: '时间', dataIndex: 'at', render: fmtTime },
                    { title: '设备', dataIndex: 'device', render: (v) => v ?? '—' },
                    { title: '系统', dataIndex: 'os', render: (v) => v ?? '—' },
                    { title: '版本', dataIndex: 'appVersion', render: (v) => v ?? '—' },
                    { title: 'IP', dataIndex: 'ip', render: (v) => v ?? '—' },
                  ]}
                />
              )}
            </FormSection>

            <FormSection title="管理操作">
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
            </FormSection>
          </>
        )}
      </AdminModal>

      <AdminModal
        title="补发荣誉 / 足迹"
        open={grantOpen}
        onCancel={() => setGrantOpen(false)}
        onOk={handleGrant}
        confirmLoading={grantSaving}
        okText="补发"
        width={520}
      >
        <FormField label="勋章" hint="已拥有的不在列表中">
          <Checkbox.Group
            value={grantAchvs}
            onChange={(v) => setGrantAchvs(v as string[])}
            options={achvDefs
              .filter((a) => !(u?.achievements ?? {})[a.slug])
              .map((a) => ({ label: a.name, value: a.slug }))}
          />
        </FormField>
        <FormField label="景点打卡" hint="输入景点名后回车，可多个">
          <Select
            mode="tags"
            style={{ width: '100%' }}
            placeholder="如：故宫"
            value={grantSpots}
            onChange={setGrantSpots}
            open={false}
          />
        </FormField>
      </AdminModal>
    </>
  );
}
