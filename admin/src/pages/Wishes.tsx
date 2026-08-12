import { useState } from 'react';
import { Input, Tag } from 'antd';
import { useSearchParams } from 'react-router-dom';
import CrudTable from '../components/CrudTable';
import { fmtTime } from '../paged';

export default function Wishes() {
  const [params] = useSearchParams();
  const [uid, setUid] = useState(params.get('uid') ?? '');

  return (
    <CrudTable
      col="wishes"
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
        { title: '标题', dataIndex: 'title' },
        { title: '用户', dataIndex: 'uid', width: 170, render: (v) => <code style={{ fontSize: 12 }}>{v}</code> },
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
  );
}
