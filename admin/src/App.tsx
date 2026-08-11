import { Layout, Menu, Button, type MenuProps } from 'antd';
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

const menuItems: MenuProps['items'] = [
  { key: '/', label: '概览' },
  { key: '/users', label: '用户' },
  { key: '/feedback', label: '反馈' },
  { key: '/login-logs', label: '登录日志' },
  { key: '/events', label: '行为事件' },
  {
    type: 'group',
    label: '数据表',
    children: [
      { key: '/wishes', label: '心愿' },
      { key: '/tasks', label: '任务' },
      { key: '/capsules', label: '时光胶囊' },
    ],
  },
  {
    type: 'group',
    label: '内容配置',
    children: [
      { key: '/default-lists', label: '默认清单' },
      { key: '/milestone-templates', label: '里程碑模板' },
      { key: '/images', label: '图片素材' },
      { key: '/honors', label: '荣誉定义' },
      { key: '/attractions', label: '景点库' },
      { key: '/blocked-words', label: '屏蔽词' },
      { key: '/announcements', label: '公告与版本' },
      { key: '/demo-users', label: '演示用户' },
    ],
  },
  { key: '/audit-log', label: '操作日志' },
];

function AdminLayout() {
  const navigate = useNavigate();
  const location = useLocation();

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Layout.Sider width={200}>
        <div style={{ color: '#fff', textAlign: 'center', padding: 16, fontWeight: 'bold' }}>
          人生清单
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[location.pathname]}
          items={menuItems}
          onClick={({ key }) => navigate(key)}
        />
      </Layout.Sider>
      <Layout>
        <Layout.Header
          style={{
            background: '#fff',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 24px',
          }}
        >
          <span style={{ fontSize: 18, fontWeight: 'bold' }}>人生清单 · 管理端</span>
          <Button onClick={clearKey}>退出登录</Button>
        </Layout.Header>
        <Layout.Content style={{ margin: 24, background: '#fff' }}>
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
