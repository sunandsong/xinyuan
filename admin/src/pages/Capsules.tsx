import { Tag, Typography } from 'antd';
import { letterForm } from '../crudForms';
import CrudTable from '../components/CrudTable';
import UserDrilldownPage from '../components/UserDrilldownPage';
import { fmtTime } from '../paged';

export default function Capsules() {
  return (
    <UserDrilldownPage
      subtitle="先搜索并选择用户，再查看该用户的时光胶囊"
      actionLabel="查看胶囊"
      userFilter="letters"
      statColumn={{ title: '胶囊', render: (r) => r.letterTotal ?? 0 }}
      summary={(_, c) => `胶囊 ${c.letters} 封`}
    >
      {(uid) => (
        <CrudTable
          embedded
          col="letters"
          softDelete
          editForm={letterForm}
          where={{ uid }}
          columns={[
            { title: '标题', dataIndex: 'title', width: 180 },
            {
              title: '正文',
              dataIndex: 'content',
              render: (v) => (
                <Typography.Paragraph
                  style={{ marginBottom: 0, maxWidth: 420 }}
                  ellipsis={{ rows: 1, expandable: true, symbol: '展开' }}
                >
                  {v}
                </Typography.Paragraph>
              ),
            },
            { title: '写于', dataIndex: 'createdAt', width: 150, render: (v) => fmtTime(v) },
            { title: '开启时间', dataIndex: 'openAt', width: 150, render: (v) => fmtTime(v) },
            {
              title: '状态',
              dataIndex: 'openAt',
              key: 'state',
              width: 90,
              render: (v) => (v && v <= Date.now() ? <Tag color="green">可开启</Tag> : <Tag>未到期</Tag>),
            },
          ]}
        />
      )}
    </UserDrilldownPage>
  );
}
