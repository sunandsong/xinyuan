import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { ArrowLeftOutlined } from '@ant-design/icons';
import { Button, Input, Space, message } from 'antd';
import { useSearchParams } from 'react-router-dom';
import { api } from '../api';
import { ActionBtn, TableActions } from './TableActions';
import AvatarCell from './AvatarCell';
import AdminTable from './AdminTable';
import EmptyState from './EmptyState';
import TablePage from './TablePage';
import { DEFAULT_TABLE_PAGE_SIZE } from '../tableConfig';
import { MUTED } from '../theme';

export interface UserListRow {
  _id: string;
  account?: string;
  nickname?: string;
  avatarUrl?: string | null;
  wishTotal: number;
  wishDone: number;
  taskTotal?: number;
  letterTotal?: number;
}

interface UserCounts {
  wishes: number;
  tasks: number;
  letters: number;
}

export type UserDrilldownFilter = 'wishes' | 'tasks' | 'letters';

const FILTER_QUERY: Record<UserDrilldownFilter, string> = {
  wishes: 'hasWishes=1',
  tasks: 'hasTasks=1',
  letters: 'hasLetters=1',
};

/** 数据表通用：先搜用户，再穿透该用户的子表 */
export default function UserDrilldownPage({
  subtitle,
  actionLabel,
  userFilter,
  statColumn,
  summary,
  children,
}: {
  subtitle: string;
  actionLabel: string;
  userFilter: UserDrilldownFilter;
  statColumn?: { title: string; render: (row: UserListRow) => ReactNode };
  summary: (user: UserListRow, counts: UserCounts) => ReactNode;
  children: (uid: string) => ReactNode;
}) {
  const [params, setParams] = useSearchParams();
  const selectedUid = params.get('uid') ?? '';

  const [rows, setRows] = useState<UserListRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(DEFAULT_TABLE_PAGE_SIZE);
  const [q, setQ] = useState('');
  const [loading, setLoading] = useState(false);
  const [selectedUser, setSelectedUser] = useState<UserListRow | null>(null);
  const [counts, setCounts] = useState<UserCounts | null>(null);

  const loadUsers = useCallback(
    (p = page, kw = q, size = pageSize) => {
      setLoading(true);
      api
        .get(
          `/admin/users?q=${encodeURIComponent(kw)}&sort=lastActiveAt&skip=${(p - 1) * size}&limit=${size}&${FILTER_QUERY[userFilter]}`,
        )
        .then((d) => {
          setRows(d.items);
          setTotal(d.total);
        })
        .catch((e) => message.error(`加载失败：${e.message}`))
        .finally(() => setLoading(false));
    },
    [page, q, pageSize, userFilter],
  );

  useEffect(() => {
    if (selectedUid) return;
    loadUsers();
  }, [selectedUid, loadUsers]);

  useEffect(() => {
    if (!selectedUid) {
      setSelectedUser(null);
      setCounts(null);
      return;
    }
    api
      .get(`/admin/users/${selectedUid}`)
      .then((d) => {
        setSelectedUser({
          _id: d.user._id,
          account: d.user.account,
          nickname: d.user.nickname,
          avatarUrl: d.user.avatarUrl,
          wishTotal: d.counts.wishes,
          wishDone: d.user.doneCount ?? 0,
          taskTotal: d.counts.tasks,
          letterTotal: d.counts.letters,
        });
        setCounts(d.counts);
      })
      .catch((e) => {
        message.error(`用户加载失败：${e.message}`);
        setParams({});
      });
  }, [selectedUid, setParams]);

  function onPageChange(p: number, size: number) {
    if (size !== pageSize) {
      setPageSize(size);
      setPage(1);
      loadUsers(1, q, size);
      return;
    }
    setPage(p);
    loadUsers(p, q, size);
  }

  if (selectedUid) {
    const u = selectedUser;
    const c = counts;
    return (
      <TablePage
        toolbar={
          <Space wrap>
            <Button icon={<ArrowLeftOutlined />} onClick={() => setParams({})}>
              返回选用户
            </Button>
            {u && c ? (
              <Space>
                <AvatarCell url={u.avatarUrl} name={u.nickname} />
                <span style={{ fontWeight: 600 }}>{u.nickname || u.account || u._id}</span>
                <span style={{ color: MUTED, fontSize: 13 }}>
                  {u.account ? `${u.account} · ` : ''}
                  {summary(u, c)}
                </span>
              </Space>
            ) : (
              <span style={{ color: MUTED }}>加载用户…</span>
            )}
          </Space>
        }
      >
        {u && c ? children(selectedUid) : <EmptyState height={200}>加载中…</EmptyState>}
      </TablePage>
    );
  }

  const columns = [
    {
      title: '用户',
      render: (_: unknown, r: UserListRow) => (
        <Space>
          <AvatarCell url={r.avatarUrl} name={r.nickname} />
          <span>
            <div>{r.nickname || '—'}</div>
            <div style={{ color: MUTED, fontSize: 12 }}>{r.account}</div>
          </span>
        </Space>
      ),
    },
    ...(statColumn
      ? [{ title: statColumn.title, width: 100, render: (_: unknown, r: UserListRow) => statColumn.render(r) }]
      : []),
    {
      title: '操作',
      width: 110,
      render: (_: unknown, r: UserListRow) => (
        <TableActions>
          <ActionBtn variant="primary" onClick={() => setParams({ uid: r._id })}>
            {actionLabel}
          </ActionBtn>
        </TableActions>
      ),
    },
  ];

  return (
    <TablePage
      subtitle={subtitle}
      toolbar={
        <Space wrap>
          <Input.Search
            placeholder="搜账号 / 昵称"
            allowClear
            style={{ width: 260 }}
            onSearch={(v) => {
              setQ(v);
              setPage(1);
              loadUsers(1, v);
            }}
          />
          <span style={{ color: MUTED, fontSize: 13 }}>共 {total} 人</span>
        </Space>
      }
    >
      <AdminTable<UserListRow>
        rowKey="_id"
        loading={loading}
        dataSource={rows}
        size="middle"
        locale={{ emptyText: <EmptyState height={160}>没有匹配的用户</EmptyState> }}
        paginationBind={{ page, pageSize, total, onChange: onPageChange, unit: '人' }}
        columns={columns}
      />
    </TablePage>
  );
}
