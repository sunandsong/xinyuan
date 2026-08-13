import { useRef } from 'react';
import { Switch, message } from 'antd';
import { ArrowDownOutlined, ArrowUpOutlined } from '@ant-design/icons';
import { api } from '../api';
import { presetWishForm } from '../crudForms';
import CrudTable from '../components/CrudTable';
import { ActionBtn, TableActions } from '../components/TableActions';

interface PresetWish {
  _id: string;
  title: string;
  sort?: number;
  enabled?: boolean;
}

/** 默认清单（preset_wishes）：新注册用户的 50 条人生清单来源。
 * 排序上移/下移 = 跟相邻行交换 sort 值；启停走行内开关。 */
export default function DefaultLists() {
  const refresh = useRef<(() => void) | null>(null);
  const rowsRef = useRef<PresetWish[]>([]);

  async function setEnabled(row: PresetWish, enabled: boolean) {
    try {
      await api.post('/admin/content/preset_wishes', { id: row._id, doc: { enabled } });
      refresh.current?.();
    } catch (e: any) {
      message.error(`操作失败：${e.message}`);
    }
  }

  async function move(row: PresetWish, dir: -1 | 1) {
    const sorted = [...rowsRef.current].sort((a, b) => (a.sort ?? 0) - (b.sort ?? 0));
    const i = sorted.findIndex((r) => r._id === row._id);
    const j = i + dir;
    if (i < 0 || j < 0 || j >= sorted.length) return;
    const other = sorted[j];
    try {
      await Promise.all([
        api.post('/admin/content/preset_wishes', { id: row._id, doc: { sort: other.sort ?? 0 } }),
        api.post('/admin/content/preset_wishes', { id: other._id, doc: { sort: row.sort ?? 0 } }),
      ]);
      refresh.current?.();
    } catch (e: any) {
      message.error(`移动失败：${e.message}`);
    }
  }

  return (
    <CrudTable
      col="preset_wishes"
      refreshRef={refresh}
      editForm={presetWishForm}
      creatable
      onData={(items) => {
        rowsRef.current = items;
      }}
      columns={[
        {
          title: '排序',
          dataIndex: 'sort',
          width: 70,
          sorter: (a: PresetWish, b: PresetWish) => (a.sort ?? 0) - (b.sort ?? 0),
          defaultSortOrder: 'ascend',
        },
        { title: '标题', dataIndex: 'title' },
        {
          title: '启用',
          dataIndex: 'enabled',
          width: 90,
          render: (v: boolean | undefined, row: PresetWish) => (
            <Switch size="small" checked={v !== false} onChange={(c) => setEnabled(row, c)} />
          ),
        },
        {
          title: '位置',
          width: 100,
          render: (_: unknown, row: PresetWish) => (
            <TableActions>
              <ActionBtn icon={<ArrowUpOutlined />} onClick={() => move(row, -1)} />
              <ActionBtn icon={<ArrowDownOutlined />} onClick={() => move(row, 1)} />
            </TableActions>
          ),
        },
      ]}
    />
  );
}
