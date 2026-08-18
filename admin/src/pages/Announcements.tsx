import { useEffect, useState } from 'react';
import {
  Button,
  DatePicker,
  Input,
  Popconfirm,
  Space,
  Switch,
  Tag,
  message,
} from 'antd';
import dayjs, { type Dayjs } from 'dayjs';
import { api } from '../api';
import { FormField, FormSwitchRow } from '../components/AdminForm';
import AdminModal from '../components/AdminModal';
import AdminTable from '../components/AdminTable';
import ContentCard from '../components/ContentCard';
import EmptyState from '../components/EmptyState';
import { ActionBtn, TableActions } from '../components/TableActions';
import TablePage from '../components/TablePage';
import { CARD_STYLE, MUTED } from '../theme';
import { fmtTime, usePagedList } from '../paged';

/** announcements 集合里存最低版本号的特殊文档 id（跟后端 config.ts 约定一致） */
const MIN_VERSION_ID = 'sys_min_version';
/** 同上，存功能开关的特殊文档 id */
const FEATURES_ID = 'sys_features';

interface Ann {
  _id: string;
  title?: string;
  body?: string;
  startAt?: number;
  endAt?: number;
  enabled?: boolean;
}

interface Editing {
  id: string;
  title: string;
  body: string;
  range: [Dayjs, Dayjs] | null;
  enabled: boolean;
}

export default function Announcements() {
  const { items, pagination, loading, reload } = usePagedList<Ann>(
    '/admin/content/announcements',
    {},
  );
  // 两个 sys_ 文档是配置不是公告，不进列表
  const list = items.filter((a) => a._id !== MIN_VERSION_ID && a._id !== FEATURES_ID);

  const [editing, setEditing] = useState<Editing | null>(null);
  const [saving, setSaving] = useState(false);

  // 强更版本卡
  const [minVersion, setMinVersion] = useState('');
  const [mvLoaded, setMvLoaded] = useState(false);
  const [mvSaving, setMvSaving] = useState(false);

  // 功能开关卡：排行榜显隐（送审期间关掉，审核员就看不到榜单里的演示数据）
  const [showRank, setShowRank] = useState(true);
  // 通知提醒显隐。首发不带这个功能，关掉之后 App 里连入口都不出现，
  // 也不会申请通知权限；哪天想放出来再打开，不用发版
  const [showNotif, setShowNotif] = useState(true);
  // 数据留存清理总开关。默认关，跟后端 cleanupEnabled() 的兜底一致——
  // 这是会物理删数据的自动任务，配置读不到时宁可不跑
  const [cleanupOn, setCleanupOn] = useState(false);
  const [featLoaded, setFeatLoaded] = useState(false);
  const [featSaving, setFeatSaving] = useState(false);

  useEffect(() => {
    api
      .get(`/admin/content/announcements?f__id=${MIN_VERSION_ID}`)
      .then((d) => setMinVersion(String(d.items[0]?.value ?? '')))
      .catch(() => {})
      .finally(() => setMvLoaded(true));
    api
      .get(`/admin/content/announcements?f__id=${FEATURES_ID}`)
      .then((d) => {
        // 排行榜查不到就是还没配过，按「开」处理，跟后端 fetchFeatures 的兜底一致
        setShowRank(d.items[0]?.showRank !== false);
        setShowNotif(d.items[0]?.showNotif !== false);
        // 清理开关相反，必须显式为 true 才算开
        setCleanupOn(d.items[0]?.cleanupEnabled === true);
      })
      .catch(() => {})
      .finally(() => setFeatLoaded(true));
  }, []);

  async function saveCleanup(next: boolean) {
    setFeatSaving(true);
    try {
      await api.post('/admin/content/announcements', {
        id: FEATURES_ID,
        doc: { cleanupEnabled: next, enabled: false },
      });
      setCleanupOn(next);
      message.success(next ? '数据留存清理已开启（每天 04:00 自动执行）' : '数据留存清理已停止');
    } catch (e: any) {
      message.error(`保存失败：${e.message}`);
    } finally {
      setFeatSaving(false);
    }
  }

  async function saveShowRank(next: boolean) {
    setFeatSaving(true);
    try {
      await api.post('/admin/content/announcements', {
        id: FEATURES_ID,
        doc: { showRank: next, enabled: false }, // enabled:false 免得被当公告下发
      });
      setShowRank(next);
      message.success(next ? '排行榜已对用户开放' : '排行榜已隐藏');
    } catch (e: any) {
      message.error(`保存失败：${e.message}`);
    } finally {
      setFeatSaving(false);
    }
  }

  async function saveShowNotif(next: boolean) {
    setFeatSaving(true);
    try {
      await api.post('/admin/content/announcements', {
        id: FEATURES_ID,
        doc: { showNotif: next, enabled: false }, // enabled:false 免得被当公告下发
      });
      setShowNotif(next);
      message.success(next ? '通知提醒已对用户开放' : '通知提醒已隐藏');
    } catch (e: any) {
      message.error(`保存失败：${e.message}`);
    } finally {
      setFeatSaving(false);
    }
  }

  async function saveMinVersion() {
    setMvSaving(true);
    try {
      await api.post('/admin/content/announcements', {
        id: MIN_VERSION_ID,
        doc: { value: minVersion.trim(), enabled: false }, // enabled:false 免得被当公告下发
      });
      message.success('最低版本已保存');
    } catch (e: any) {
      message.error(`保存失败：${e.message}`);
    } finally {
      setMvSaving(false);
    }
  }

  async function save() {
    if (!editing) return;
    if (!editing.title.trim()) {
      message.warning('标题不能为空');
      return;
    }
    setSaving(true);
    try {
      await api.post('/admin/content/announcements', {
        id: editing.id || undefined,
        doc: {
          title: editing.title.trim(),
          body: editing.body,
          // 时间范围写毫秒时间戳（App 端按 startAt <= now <= endAt 生效）
          startAt: editing.range ? editing.range[0].valueOf() : null,
          endAt: editing.range ? editing.range[1].valueOf() : null,
          enabled: editing.enabled,
        },
      });
      message.success('已保存');
      setEditing(null);
      reload();
    } catch (e: any) {
      message.error(`保存失败：${e.message}`);
    } finally {
      setSaving(false);
    }
  }

  async function remove(id: string) {
    try {
      await api.post('/admin/content/announcements/delete', { id });
      message.success('已删除');
      reload();
    } catch (e: any) {
      message.error(`删除失败：${e.message}`);
    }
  }

  const now = Date.now();

  return (
    <TablePage
      extra={
        <ContentCard padding="16px 20px" style={{ ...CARD_STYLE, marginBottom: 16 }}>
          <div style={{ fontWeight: 600, marginBottom: 12 }}>强更版本</div>
          <Space wrap>
            <Input
              placeholder="如 1.2.0（低于此版本的 App 提示强制更新）"
              style={{ width: 320 }}
              value={minVersion}
              disabled={!mvLoaded}
              onChange={(e) => setMinVersion(e.target.value)}
            />
            <Button type="primary" loading={mvSaving} onClick={saveMinVersion}>
              保存
            </Button>
            <span style={{ color: MUTED, fontSize: 12 }}>留空 = 不强更</span>
          </Space>
          <div style={{ fontWeight: 600, margin: '20px 0 12px' }}>功能开关</div>
          <Space wrap>
            <Switch
              checked={showRank}
              disabled={!featLoaded || featSaving}
              onChange={saveShowRank}
            />
            <span>对用户显示排行榜</span>
            <span style={{ color: MUTED, fontSize: 12 }}>
              应用商店送审期间建议关掉（榜单含演示数据），过审后再打开，改完用户切后台再回来即生效
            </span>
          </Space>
          <div style={{ marginTop: 12 }}>
            <Space wrap>
              <Switch
                checked={showNotif}
                disabled={!featLoaded || featSaving}
                onChange={saveShowNotif}
              />
              <span>对用户显示通知提醒</span>
              <span style={{ color: MUTED, fontSize: 12 }}>
                关掉后「我的」里不出现通知设置入口，也不再申请通知权限、不排提醒
              </span>
            </Space>
          </div>
          <div style={{ marginTop: 12 }}>
            <Space wrap>
              <Switch
                checked={cleanupOn}
                disabled={!featLoaded || featSaving}
                onChange={saveCleanup}
              />
              <span>数据留存清理</span>
              <span style={{ color: MUTED, fontSize: 12 }}>
                每天 04:00 物理删除过期数据（登录日志/行为事件 90 天、崩溃 180 天、
                已处理反馈 1 年、注销用户 30 天）。<b>删除不可恢复</b>，
                隐私政策第七节已按这些天数对用户公示——长期关着等于承诺没兑现
              </span>
            </Space>
          </div>
        </ContentCard>
      }
      toolbar={
        <Space>
          <Button
            type="primary"
            onClick={() => setEditing({ id: '', title: '', body: '', range: null, enabled: true })}
          >
            发公告
          </Button>
          <span style={{ color: MUTED, fontSize: 13 }}>共 {pagination.total} 条公告</span>
        </Space>
      }
    >
      <AdminTable<Ann>
        rowKey="_id"
        loading={loading}
        dataSource={list}
        size="middle"
        locale={{ emptyText: <EmptyState height={160}>暂无公告</EmptyState> }}
        paginationBind={pagination}
        columns={[
          { title: '标题', dataIndex: 'title' },
          { title: '内容', dataIndex: 'body', render: (v) => <span style={{ whiteSpace: 'pre-wrap' }}>{v}</span> },
          { title: '开始', dataIndex: 'startAt', width: 150, render: (v) => fmtTime(v) },
          { title: '结束', dataIndex: 'endAt', width: 150, render: (v) => fmtTime(v) },
          {
            title: '状态',
            width: 90,
            render: (_, a) => {
              if (a.enabled === false) return <Tag>停用</Tag>;
              const started = (a.startAt ?? -Infinity) <= now;
              const ended = now > (a.endAt ?? Infinity);
              if (!started) return <Tag color="blue">未开始</Tag>;
              if (ended) return <Tag>已结束</Tag>;
              return <Tag color="green">生效中</Tag>;
            },
          },
          {
            title: '操作',
            width: 148,
            render: (_, a) => (
              <TableActions>
                <ActionBtn
                  variant="primary"
                  onClick={() =>
                    setEditing({
                      id: a._id,
                      title: a.title ?? '',
                      body: a.body ?? '',
                      range: a.startAt && a.endAt ? [dayjs(a.startAt), dayjs(a.endAt)] : null,
                      enabled: a.enabled !== false,
                    })
                  }
                >
                  编辑
                </ActionBtn>
                <Popconfirm title="删除这条公告？" onConfirm={() => remove(a._id)}>
                  <ActionBtn variant="danger">删除</ActionBtn>
                </Popconfirm>
              </TableActions>
            ),
          },
        ]}
      />

      <AdminModal
        title={editing?.id ? '编辑公告' : '发公告'}
        open={editing !== null}
        onCancel={() => setEditing(null)}
        onOk={save}
        confirmLoading={saving}
        okText={editing?.id ? '保存' : '发布'}
        width={560}
      >
        <FormField label="标题" required>
          <Input
            value={editing?.title ?? ''}
            onChange={(e) => setEditing((c) => (c ? { ...c, title: e.target.value } : c))}
          />
        </FormField>
        <FormField label="内容">
          <Input.TextArea
            rows={4}
            value={editing?.body ?? ''}
            onChange={(e) => setEditing((c) => (c ? { ...c, body: e.target.value } : c))}
          />
        </FormField>
        <FormField label="生效时间" hint="不填则一直生效">
          <DatePicker.RangePicker
            showTime
            style={{ width: '100%' }}
            value={editing?.range ?? null}
            onChange={(v) =>
              setEditing((c) => (c ? { ...c, range: v && v[0] && v[1] ? [v[0], v[1]] : null } : c))
            }
          />
        </FormField>
        <FormSwitchRow
          label="启用"
          checked={editing?.enabled ?? true}
          onChange={(v) => setEditing((c) => (c ? { ...c, enabled: v } : c))}
        />
      </AdminModal>
    </TablePage>
  );
}
