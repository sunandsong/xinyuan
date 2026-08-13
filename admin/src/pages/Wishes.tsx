import { Tag } from 'antd';
import { wishForm } from '../crudForms';
import CrudTable from '../components/CrudTable';
import UserDrilldownPage from '../components/UserDrilldownPage';
import { fmtTime } from '../paged';

export default function Wishes() {
  return (
    <UserDrilldownPage
      subtitle="先搜索并选择用户，再查看该用户的心愿列表"
      actionLabel="查看心愿"
      userFilter="wishes"
      statColumn={{ title: '心愿', render: (r) => `${r.wishDone}/${r.wishTotal}` }}
      summary={(u) => `心愿 ${u.wishDone}/${u.wishTotal}`}
    >
      {(uid) => (
        <CrudTable
          embedded
          col="wishes"
          softDelete
          editForm={wishForm}
          where={{ uid }}
          columns={[
            { title: '标题', dataIndex: 'title' },
            {
              title: '状态',
              dataIndex: 'done',
              width: 90,
              render: (v) => (v ? <Tag color="green">已实现</Tag> : <Tag>进行中</Tag>),
            },
            { title: '实现时间', dataIndex: 'doneAt', width: 150, render: (v) => fmtTime(v) },
            { title: '地点', dataIndex: 'location', width: 120, render: (v) => v ?? '—' },
            { title: '里程碑', dataIndex: 'steps', width: 80, render: (v) => v?.length ?? 0 },
            { title: '照片', dataIndex: 'photos', width: 70, render: (v) => v?.length ?? 0 },
            { title: '更新时间', dataIndex: 'updatedAt', width: 150, render: (v) => fmtTime(v) },
          ]}
        />
      )}
    </UserDrilldownPage>
  );
}
