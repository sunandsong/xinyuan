import { useState } from 'react';
import { Input, Tag } from 'antd';
import { useSearchParams } from 'react-router-dom';
import CrudTable from '../components/CrudTable';
import { fmtTime } from '../paged';

export default function Tasks() {
  const [params] = useSearchParams();
  const [uid, setUid] = useState(params.get('uid') ?? '');

  return (
    <CrudTable
      col="tasks"
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
  );
}
