import { useEffect, useMemo, useState } from 'react';
import { Badge, Button, Layout, Menu, type MenuProps } from 'antd';
import {
  DashboardOutlined,
  TeamOutlined,
  MessageOutlined,
  LoginOutlined,
  ThunderboltOutlined,
  BugOutlined,
  UserDeleteOutlined,
  DatabaseOutlined,
  StarOutlined,
  CheckSquareOutlined,
  MailOutlined,
  AppstoreOutlined,
  UnorderedListOutlined,
  NodeIndexOutlined,
  PictureOutlined,
  TrophyOutlined,
  EnvironmentOutlined,
  StopOutlined,
  NotificationOutlined,
  UserSwitchOutlined,
  FileSearchOutlined,
  LogoutOutlined,
} from '@ant-design/icons';
import { Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom';
import { api, clearKey, useKey } from './api';
import BrandLogo from './components/BrandLogo';
import Gate from './Gate';
import Overview from './pages/Overview';
import Users from './pages/Users';
import Feedback from './pages/Feedback';
import LoginLogs from './pages/LoginLogs';
import Events from './pages/Events';
import Wishes from './pages/Wishes';
import Tasks from './pages/Tasks';
import Capsules from './pages/Capsules';
import DefaultLists from './pages/DefaultLists';
import MilestoneTemplates from './pages/MilestoneTemplates';
import Images from './pages/Images';
import Honors from './pages/Honors';
import Attractions from './pages/Attractions';
import BlockedWords from './pages/BlockedWords';
import Announcements from './pages/Announcements';
import DemoUsers from './pages/DemoUsers';
import AuditLog from './pages/AuditLog';
import Crashes from './pages/Crashes';
import DeletionRequests from './pages/DeletionRequests';
import { BG, GRADIENT, INK, LINE, MUTED, PAGE_META } from './theme';

const menuItems: MenuProps['items'] = [
  { key: '/', icon: <DashboardOutlined />, label: '首页' },
  { key: '/users', icon: <TeamOutlined />, label: '用户' },
  { key: '/feedback', icon: <MessageOutlined />, label: '反馈' },
  { key: '/login-logs', icon: <LoginOutlined />, label: '登录日志' },
  { key: '/events', icon: <ThunderboltOutlined />, label: '行为事件' },
  { key: '/crashes', icon: <BugOutlined />, label: '崩溃' },
  { key: '/deletion-requests', icon: <UserDeleteOutlined />, label: '注销申请' },
  {
    key: 'group-data',
    icon: <DatabaseOutlined />,
    label: '数据表',
    children: [
      { key: '/wishes', icon: <StarOutlined />, label: '心愿' },
      { key: '/tasks', icon: <CheckSquareOutlined />, label: '任务' },
      { key: '/capsules', icon: <MailOutlined />, label: '时光胶囊' },
    ],
  },
  {
    key: 'group-content',
    icon: <AppstoreOutlined />,
    label: '内容配置',
    children: [
      { key: '/default-lists', icon: <UnorderedListOutlined />, label: '默认清单' },
      { key: '/milestone-templates', icon: <NodeIndexOutlined />, label: '里程碑模板' },
      { key: '/images', icon: <PictureOutlined />, label: '图片素材' },
      { key: '/honors', icon: <TrophyOutlined />, label: '荣誉定义' },
      { key: '/attractions', icon: <EnvironmentOutlined />, label: '景点库' },
      { key: '/blocked-words', icon: <StopOutlined />, label: '屏蔽词' },
      { key: '/announcements', icon: <NotificationOutlined />, label: '公告与版本' },
      { key: '/demo-users', icon: <UserSwitchOutlined />, label: '演示用户' },
    ],
  },
  { key: '/audit-log', icon: <FileSearchOutlined />, label: '操作日志' },
];

const GROUP_OF: Record<string, string> = {
  '/wishes': 'group-data',
  '/tasks': 'group-data',
  '/capsules': 'group-data',
  '/default-lists': 'group-content',
  '/milestone-templates': 'group-content',
  '/images': 'group-content',
  '/honors': 'group-content',
  '/attractions': 'group-content',
  '/blocked-words': 'group-content',
  '/announcements': 'group-content',
  '/demo-users': 'group-content',
};

/** 待办角标数：进后台拉一次，之后每次切页重拉（处理完角标会自己消失）。
 * 注销申请堆着不处理就是违反 Google Play 的删除要求；崩溃堆着不看则是
 * 「线上崩了但没人知道」——两个都得在侧边栏能一眼看见。 */
function usePendingCounts(dep: string): { deletions: number; crashes: number } {
  const [n, setN] = useState({ deletions: 0, crashes: 0 });
  useEffect(() => {
    let cancelled = false;
    Promise.all([
      api.get('/admin/deletion-requests?handled=false&limit=1').catch(() => null),
      api.get('/admin/crashes?resolved=false&limit=1').catch(() => null),
    ]).then(([d, c]) => {
      if (cancelled) return;
      setN({ deletions: Number(d?.total) || 0, crashes: Number(c?.total) || 0 });
    });
    return () => {
      cancelled = true;
    };
  }, [dep]);
  return n;
}

/** 给菜单项挂角标：n>0 才挂，处理完自动消失 */
function withBadge(item: any, n: number, label: string) {
  if (!item || n <= 0) return item;
  return {
    ...item,
    label: (
      <Badge count={n} size="small" offset={[10, 0]}>
        {label}
      </Badge>
    ),
  };
}

function AdminLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const pending = usePendingCounts(location.pathname);
  const items = useMemo(
    () =>
      (menuItems ?? []).map((it) => {
        if (!it || !('key' in it)) return it;
        if (it.key === '/deletion-requests') return withBadge(it, pending.deletions, '注销申请');
        if (it.key === '/crashes') return withBadge(it, pending.crashes, '崩溃');
        return it;
      }),
    [pending],
  );
  const [openKeys, setOpenKeys] = useState<string[]>(() => {
    const g = GROUP_OF[location.pathname];
    return g ? [g] : [];
  });

  const meta = PAGE_META[location.pathname] ?? { title: '管理端' };

  return (
    <Layout style={{ height: '100vh', overflow: 'hidden' }}>
      <Layout.Sider
        width={220}
        theme="light"
        style={{
          height: '100vh',
          overflowY: 'auto',
          borderRight: `1px solid ${LINE}`,
          background: '#fff',
        }}
      >
        <div style={{ background: GRADIENT, height: 3 }} />
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            padding: '20px 20px 16px',
          }}
        >
          <BrandLogo size={36} />
          <div>
            <div style={{ fontWeight: 700, fontSize: 15, color: INK, lineHeight: 1.2 }}>人生清单</div>
            <div style={{ fontSize: 12, color: MUTED, marginTop: 2 }}>管理后台</div>
          </div>
        </div>
        <Menu
          theme="light"
          mode="inline"
          selectedKeys={[location.pathname]}
          openKeys={openKeys}
          onOpenChange={(keys) => setOpenKeys(keys)}
          items={items}
          onClick={({ key }) => navigate(key)}
          style={{ borderInlineEnd: 'none' }}
        />
      </Layout.Sider>
      <Layout style={{ height: '100vh' }}>
        <Layout.Header
          style={{
            flexShrink: 0,
            background: '#fff',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 24px',
            borderBottom: `1px solid ${LINE}`,
            height: 56,
          }}
        >
          <div style={{ fontSize: 18, fontWeight: 600, color: INK, lineHeight: 1.3 }}>
            {meta.title}
          </div>
          <Button icon={<LogoutOutlined />} onClick={clearKey}>
            退出登录
          </Button>
        </Layout.Header>
        <Layout.Content style={{ background: BG, overflow: 'hidden', minHeight: 0 }}>
          <Routes>
            <Route path="/" element={<Overview />} />
            <Route path="/users" element={<Users />} />
            <Route path="/feedback" element={<Feedback />} />
            <Route path="/login-logs" element={<LoginLogs />} />
            <Route path="/events" element={<Events />} />
            <Route path="/wishes" element={<Wishes />} />
            <Route path="/tasks" element={<Tasks />} />
            <Route path="/capsules" element={<Capsules />} />
            <Route path="/default-lists" element={<DefaultLists />} />
            <Route path="/milestone-templates" element={<MilestoneTemplates />} />
            <Route path="/images" element={<Images />} />
            <Route path="/honors" element={<Honors />} />
            <Route path="/attractions" element={<Attractions />} />
            <Route path="/blocked-words" element={<BlockedWords />} />
            <Route path="/announcements" element={<Announcements />} />
            <Route path="/demo-users" element={<DemoUsers />} />
            <Route path="/crashes" element={<Crashes />} />
            <Route path="/deletion-requests" element={<DeletionRequests />} />
            <Route path="/audit-log" element={<AuditLog />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Layout.Content>
      </Layout>
    </Layout>
  );
}

export default function App() {
  const key = useKey();
  return key ? <AdminLayout /> : <Gate />;
}
