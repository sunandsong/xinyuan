import { Tag, Tooltip } from 'antd';
import AdminTable from '../components/AdminTable';
import EmptyState from '../components/EmptyState';
import TablePage from '../components/TablePage';
import { MUTED } from '../theme';
import { fmtTime, usePagedList } from '../paged';

interface AuditRow {
  _id: string;
  action: string;
  target: string;
  detail?: Record<string, unknown> | null;
  at: number;
}

const ACTION_LABELS: Record<string, { label: string; color: string }> = {
  create: { label: '新建', color: 'green' },
  update: { label: '更新', color: 'blue' },
  delete: { label: '删除', color: 'red' },
  ban: { label: '封禁用户', color: 'red' },
  unban: { label: '解封用户', color: 'green' },
  'reset-password': { label: '重置密码', color: 'orange' },
  'reset-profile': { label: '重置资料', color: 'orange' },
  grant: { label: '补发数据', color: 'gold' },
  'demo-create': { label: '新建演示用户', color: 'green' },
  'demo-update': { label: '更新演示用户', color: 'blue' },
  'demo-delete': { label: '删除演示用户', color: 'red' },
  'demo-mark': { label: '标记演示用户', color: 'purple' },
};

const COL_LABELS: Record<string, string> = {
  users: '用户',
  feedback: '用户反馈',
  wishes: '心愿',
  tasks: '任务',
  letters: '时光胶囊',
  preset_wishes: '默认清单',
  preset_steps: '里程碑模板',
  poster_task: '任务海报',
  poster_wish: '心愿海报',
  poster_done: '完成海报',
  hero_images: 'Hero 图',
  achv_defs: '荣誉定义',
  spots: '景点',
  blockwords: '屏蔽词',
  announcements: '公告',
};

function parseTarget(target: string): { col: string; id: string } {
  const i = target.indexOf(':');
  if (i < 0) return { col: target, id: '' };
  return { col: target.slice(0, i), id: target.slice(i + 1) };
}

function formatDetail(action: string, detail?: Record<string, unknown> | null): string {
  if (!detail || typeof detail !== 'object') return '';
  if (action === 'grant') {
    const parts: string[] = [];
    if (detail.achievements) parts.push('补发成就');
    if (detail.checkins) parts.push('补发打卡');
    return parts.join('、') || '';
  }
  if (action === 'reset-profile') {
    const parts: string[] = [];
    if (detail.nickname === true) parts.push('重置昵称');
    if (detail.avatar === true) parts.push('清空头像');
    return parts.join('、') || '';
  }
  if (action === 'update' && 'handled' in detail) {
    return detail.handled ? '标记为已处理' : '标记为未处理';
  }
  if (typeof detail.note === 'string' && detail.note) {
    return `备注：${detail.note}`;
  }
  const keys = Object.keys(detail);
  if (keys.length === 0) return '';
  if (keys.length <= 3) {
    return keys.map((k) => `${k}=${String(detail[k])}`).join('，');
  }
  return `${keys.length} 项变更`;
}

export default function AuditLog() {
  const { items, pagination, loading } = usePagedList<AuditRow>('/admin/audit', {});

  return (
    <TablePage>
      <AdminTable<AuditRow>
        rowKey="_id"
        loading={loading}
        dataSource={items}
        size="middle"
        locale={{ emptyText: <EmptyState height={160}>暂无操作日志</EmptyState> }}
        paginationBind={pagination}
        columns={[
          { title: '时间', dataIndex: 'at', width: 150, render: fmtTime },
          {
            title: '操作',
            dataIndex: 'action',
            width: 120,
            render: (v: string) => {
              const meta = ACTION_LABELS[v] ?? { label: v, color: 'default' };
              return <Tag color={meta.color}>{meta.label}</Tag>;
            },
          },
          {
            title: '数据类型',
            width: 110,
            render: (_: unknown, row: AuditRow) => {
              const { col } = parseTarget(row.target);
              return COL_LABELS[col] ?? col;
            },
          },
          {
            title: '记录 ID',
            dataIndex: 'target',
            width: 200,
            render: (target: string) => {
              const { id } = parseTarget(target);
              if (!id) return <span style={{ color: MUTED }}>—</span>;
              const short = id.length > 20 ? `${id.slice(0, 8)}…${id.slice(-6)}` : id;
              return (
                <Tooltip title={id}>
                  <code style={{ fontSize: 12 }}>{short}</code>
                </Tooltip>
              );
            },
          },
          {
            title: '说明',
            dataIndex: 'detail',
            render: (detail: AuditRow['detail'], row: AuditRow) => {
              const text = formatDetail(row.action, detail);
              return text ? <span style={{ fontSize: 13 }}>{text}</span> : <span style={{ color: MUTED }}>—</span>;
            },
          },
        ]}
      />
    </TablePage>
  );
}
