import { useState } from 'react';
import { Layout, Menu, Button, type MenuProps } from 'antd';
import {
  DashboardOutlined,
  TeamOutlined,
  MessageOutlined,
  LoginOutlined,
  ThunderboltOutlined,
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
import { clearKey, useKey } from './api';
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

// 用真正的 SubMenu（有 icon，点了会展开/收起）而不是 antd 的 group 类型——
// group 只是个不可点的分类标签，子项一直平铺显示，压根没有「展开」这回事。
const menuItems: MenuProps['items'] = [
  { key: '/', icon: <DashboardOutlined />, label: '首页' },
  { key: '/users', icon: <TeamOutlined />, label: '用户' },
  { key: '/feedback', icon: <MessageOutlined />, label: '反馈' },
  { key: '/login-logs', icon: <LoginOutlined />, label: '登录日志' },
  { key: '/events', icon: <ThunderboltOutlined />, label: '行为事件' },
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

/** 当前路由在哪个分组下——刷新到子页面时对应分组要展开，不然菜单看着像迷路了 */
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

function AdminLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  // 默认展开当前路由所在的分组；用户手动折叠/展开后跟手，不强制弹回默认态
  const [openKeys, setOpenKeys] = useState<string[]>(() => {
    const g = GROUP_OF[location.pathname];
    return g ? [g] : [];
  });

  return (
    // 整页固定 100vh、禁止外层滚动；滚动只发生在右侧 Content 内部，
    // 侧栏/顶栏永远钉在原地——之前用 minHeight 撑出整页滚动，长表格一多
    // 侧边菜单和顶部标题都跟着跑没了。
    <Layout style={{ height: '100vh', overflow: 'hidden' }}>
      <Layout.Sider width={210} style={{ height: '100vh', overflowY: 'auto' }}>
        <div
          style={{
            color: '#fff',
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            padding: '18px 0 18px 24px', // 24px 跟 antd Menu 一级项的左内边距对齐
            fontWeight: 'bold',
            fontSize: 16,
          }}
        >
          <img src="/logo.png" alt="" style={{ width: 24, height: 24 }} />
          人生清单
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[location.pathname]}
          openKeys={openKeys}
          onOpenChange={(keys) => setOpenKeys(keys)}
          items={menuItems}
          onClick={({ key }) => navigate(key)}
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
          }}
        >
          <span style={{ fontSize: 18, fontWeight: 'bold' }}>人生清单 · 管理端</span>
          <Button icon={<LogoutOutlined />} onClick={clearKey}>
            退出登录
          </Button>
        </Layout.Header>
        {/* 淡灰画布跟 App 端 T.bg 对齐——各页面的白色卡片/表格铺在上面才有层次，
            之前整片纯白背景配白卡片，页面显得很平 */}
        <Layout.Content style={{ margin: 24, background: '#F2F3F7', overflowY: 'auto', minHeight: 0 }}>
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
