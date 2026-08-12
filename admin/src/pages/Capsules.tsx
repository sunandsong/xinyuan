import { useState } from 'react';
import { Input, Tag, Typography } from 'antd';
import { useSearchParams } from 'react-router-dom';
import CrudTable from '../components/CrudTable';
import { fmtTime } from '../paged';

export default function Capsules() {
  const [params] = useSearchParams();
  const [uid, setUid] = useState(params.get('uid') ?? '');

  return (
    <CrudTable
      col="letters"
      softDelete
      where={{ uid }}
      filters={
        <Input.Search
          placeholder="按 uid 过滤"
          allowClear
          defaultValue={uid}
          style={{ width: 240 }}
          onSearch={setUid}
        />
      }
      columns={[
        { title: '标题', dataIndex: 'title', width: 180 },
        {
          title: '正文',
          dataIndex: 'content',
          render: (v) => (
            // 私密内容默认折叠，点「展开」才看——别一进列表满屏都是别人的信
            <Typography.Paragraph
              style={{ marginBottom: 0, maxWidth: 420 }}
              ellipsis={{ rows: 1, expandable: true, symbol: '展开' }}
            >
              {v}
            </Typography.Paragraph>
          ),
        },
        { title: '用户', dataIndex: 'uid', width: 170, render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
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
  );
}
