import { useState } from 'react';
import { Input, Switch } from 'antd';
import { useRef } from 'react';
import { message } from 'antd';
import { api } from '../api';
import { spotForm } from '../crudForms';
import CrudTable from '../components/CrudTable';

interface Spot {
  _id: string;
  name: string;
  province?: string;
  lat?: number;
  lng?: number;
  enabled?: boolean;
}

/** 景点库（spots）：App 定位打卡的 5A 景区坐标表。 */
export default function Attractions() {
  const refresh = useRef<(() => void) | null>(null);
  const [province, setProvince] = useState('');

  async function setEnabled(row: Spot, enabled: boolean) {
    try {
      await api.post('/admin/content/spots', { id: row._id, doc: { enabled } });
      refresh.current?.();
    } catch (e: any) {
      message.error(`操作失败：${e.message}`);
    }
  }

  return (
    <CrudTable
      col="spots"
      refreshRef={refresh}
      editForm={spotForm}
      creatable
      where={{ province }}
      filters={
        <Input.Search
          placeholder="按省份筛选（如：北京）"
          allowClear
          style={{ width: 220 }}
          onSearch={setProvince}
        />
      }
      columns={[
        { title: '景点', dataIndex: 'name' },
        { title: '省份', dataIndex: 'province', width: 100 },
        { title: '纬度', dataIndex: 'lat', width: 100 },
        { title: '经度', dataIndex: 'lng', width: 100 },
        {
          title: '启用',
          dataIndex: 'enabled',
          width: 80,
          render: (v: boolean | undefined, row: Spot) => (
            <Switch size="small" checked={v !== false} onChange={(c) => setEnabled(row, c)} />
          ),
        },
      ]}
    />
  );
}
