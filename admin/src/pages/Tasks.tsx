import { Tag } from 'antd';
import { taskForm } from '../crudForms';
import CrudTable from '../components/CrudTable';
import UserDrilldownPage from '../components/UserDrilldownPage';
import { fmtTime } from '../paged';

export default function Tasks() {
  return (
    <UserDrilldownPage
      subtitle="先搜索并选择用户，再查看该用户的任务列表"
      actionLabel="查看任务"
      userFilter="tasks"
      statColumn={{ title: '任务', render: (r) => r.taskTotal ?? 0 }}
      summary={(_, c) => `任务 ${c.tasks} 条`}
    >
      {(uid) => (
        <CrudTable
          embedded
          col="tasks"
          softDelete
          editForm={taskForm}
          where={{ uid }}
          columns={[
            { title: '标题', dataIndex: 'title' },
            { title: '日期', dataIndex: 'day', width: 110 },
            {
              title: '状态',
              dataIndex: 'done',
              width: 90,
              render: (v) => (v ? <Tag color="green">已完成</Tag> : <Tag>待办</Tag>),
            },
            {
              title: '所属心愿',
              dataIndex: 'wishId',
              width: 170,
              render: (v) => (v ? <code style={{ fontSize: 12 }}>{v}</code> : '—'),
            },
            { title: '更新时间', dataIndex: 'updatedAt', width: 150, render: (v) => fmtTime(v) },
          ]}
        />
      )}
    </UserDrilldownPage>
  );
}
