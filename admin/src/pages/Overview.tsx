import { useEffect, useState } from 'react';
import { Alert, Button, Card, Col, Progress, Row, Spin, Statistic, message } from 'antd';
import { DownloadOutlined } from '@ant-design/icons';
import ReactECharts from 'echarts-for-react';
import { api } from '../api';

// ECharts 双系列色（设计稿定的浅色系）
const BLUE = '#1677ff';
const ORANGE = '#fa8c16';

interface Stats {
  totals: {
    users: number;
    todayActive: number;
    wishes: number;
    doneWishes: number;
    tasks: number;
    letters: number;
    feedbackOpen: number;
  };
  series: {
    signups: Array<[string, number]>;
    dau: Array<[string, number]>;
    logins: Array<[string, number]>;
  };
  retention: { d1: number; d7: number; d30: number };
  topEvents: Array<[string, number]>;
  topWishes: Array<{ title: string; count: number }>;
  topPlaces: Array<{ place: string; count: number }>;
  activeBuckets: { today: number; week: number; month: number; sleep: number };
}

interface Quota {
  available: boolean;
  reason?: string;
  metrics?: Record<string, { used: number | null; limit: number | null }>;
}

const QUOTA_LABELS: Record<string, string> = {
  dbRead: '数据库读（次/月）',
  dbWrite: '数据库写（次/月）',
  functionInvoke: '函数调用（次/月）',
  storage: '云存储用量',
};

/** 本月用量按日均速外推到月底，给个"照这个速度这月会用多少"的预期 */
function projectMonthEnd(used: number): number {
  const now = new Date();
  const daysElapsed = now.getDate();
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  return Math.round((used / daysElapsed) * daysInMonth);
}

/** 横向条形图：类目倒序（第一名在最上面），一个配置走天下 */
function hbarOption(data: Array<[string, number]>, color = BLUE) {
  return {
    grid: { left: 8, right: 40, top: 8, bottom: 8, containLabel: true },
    xAxis: { type: 'value', minInterval: 1 },
    yAxis: {
      type: 'category',
      data: data.map(([name]) => name),
      inverse: true,
      axisLabel: { width: 120, overflow: 'truncate' as const },
    },
    series: [
      {
        type: 'bar',
        data: data.map(([, v]) => v),
        itemStyle: { color },
        barMaxWidth: 18,
        label: { show: true, position: 'right' as const },
      },
    ],
    tooltip: { trigger: 'axis' as const },
  };
}

export default function Overview() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [quota, setQuota] = useState<Quota | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);

  useEffect(() => {
    api
      .get('/admin/stats')
      .then(setStats)
      .catch((e) => setError(String(e.message ?? e)));
    // 额度查询挂了不影响统计展示，各拉各的
    api.get('/admin/quota').then(setQuota).catch(() => setQuota({ available: false, reason: 'error' }));
  }, []);

  async function handleExport() {
    setExporting(true);
    try {
      const data = await api.get('/admin/export');
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `renshengqingdan-export-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
      if (data.truncated?.length) {
        message.warning(`以下集合超过单表导出上限被截断：${data.truncated.join('、')}`);
      }
      if (data.errored?.length) {
        message.error(`以下集合导出失败（结果里是空的，不是真没数据）：${data.errored.join('、')}`);
      }
      if (!data.truncated?.length && !data.errored?.length) {
        message.success('全库备份已下载');
      }
    } catch (e: any) {
      message.error(`导出失败：${e.message ?? e}`);
    } finally {
      setExporting(false);
    }
  }

  if (error) return <Alert type="error" message={`统计加载失败：${error}`} style={{ margin: 24 }} />;
  if (!stats)
    return (
      <div style={{ textAlign: 'center', padding: 80 }}>
        <Spin size="large" />
      </div>
    );

  const { totals, series, retention, topEvents, topWishes, topPlaces, activeBuckets } = stats;

  const statCards: Array<[string, number]> = [
    ['注册用户', totals.users],
    ['今日活跃', totals.todayActive],
    ['心愿总数', totals.wishes],
    ['已实现心愿', totals.doneWishes],
    ['任务总数', totals.tasks],
    ['时光胶囊', totals.letters],
    ['待处理反馈', totals.feedbackOpen],
  ];

  const days = series.signups.map(([d]) => d.slice(5)); // MM-DD 就够了，年份挤图

  const trendOption = {
    color: [BLUE, ORANGE],
    tooltip: { trigger: 'axis' as const },
    legend: { data: ['新增用户', 'DAU'] },
    grid: { left: 8, right: 16, top: 40, bottom: 8, containLabel: true },
    xAxis: { type: 'category' as const, data: days },
    yAxis: { type: 'value' as const, minInterval: 1 },
    series: [
      { name: '新增用户', type: 'line' as const, smooth: true, data: series.signups.map(([, v]) => v) },
      { name: 'DAU', type: 'line' as const, smooth: true, data: series.dau.map(([, v]) => v) },
    ],
  };

  const loginOption = {
    tooltip: { trigger: 'axis' as const },
    grid: { left: 8, right: 16, top: 16, bottom: 8, containLabel: true },
    xAxis: { type: 'category' as const, data: days },
    yAxis: { type: 'value' as const, minInterval: 1 },
    series: [
      {
        name: '登录次数',
        type: 'bar' as const,
        data: series.logins.map(([, v]) => v),
        itemStyle: { color: BLUE },
      },
    ],
  };

  const retentionData: Array<[string, number]> = [
    ['次日留存', Math.round(retention.d1 * 100)],
    ['7 日留存', Math.round(retention.d7 * 100)],
    ['30 日留存', Math.round(retention.d30 * 100)],
  ];
  const bucketsData: Array<[string, number]> = [
    ['今天来过', activeBuckets.today],
    ['本周来过', activeBuckets.week],
    ['本月来过', activeBuckets.month],
    ['沉睡', activeBuckets.sleep],
  ];

  return (
    <div style={{ padding: 24 }}>
      <Row gutter={[16, 16]}>
        {statCards.map(([label, value]) => (
          <Col key={label} xs={12} sm={8} md={6} lg={3}>
            <Card size="small">
              <Statistic title={label} value={value} />
            </Card>
          </Col>
        ))}
        <Col xs={12} sm={8} md={6} lg={3}>
          <Card size="small" style={{ height: '100%', display: 'flex', alignItems: 'center' }}>
            <Button icon={<DownloadOutlined />} loading={exporting} onClick={handleExport}>
              导出全库备份
            </Button>
          </Card>
        </Col>
      </Row>

      <Card title="本月资源用量" size="small" style={{ marginTop: 16 }}>
        {!quota ? (
          <Spin />
        ) : !quota.available ? (
          <span style={{ color: '#999' }}>
            未配置腾讯云密钥（TC_SECRET_ID/TC_SECRET_KEY），配置后可看数据库/函数/存储用量
          </span>
        ) : (
          <Row gutter={[24, 12]}>
            {Object.entries(quota.metrics ?? {}).map(([key, m]) => {
              const label = QUOTA_LABELS[key] ?? key;
              if (m.used == null)
                return (
                  <Col key={key} xs={24} sm={12} lg={6}>
                    <Statistic title={label} value="—" />
                  </Col>
                );
              // limit 拿得到才画进度条 + 70%/90% 预警；拿不到（目前恒 null）只显示用量和月底预估
              if (m.limit) {
                const pct = Math.round((m.used / m.limit) * 100);
                const status = pct >= 90 ? 'exception' : undefined;
                const color = pct >= 90 ? undefined : pct >= 70 ? ORANGE : BLUE;
                return (
                  <Col key={key} xs={24} sm={12} lg={6}>
                    <div style={{ marginBottom: 4 }}>{label}</div>
                    <Progress percent={pct} status={status} strokeColor={color} />
                    <div style={{ color: '#999', fontSize: 12 }}>
                      {m.used.toLocaleString()} / {m.limit.toLocaleString()}
                    </div>
                  </Col>
                );
              }
              return (
                <Col key={key} xs={24} sm={12} lg={6}>
                  <Statistic title={label} value={m.used} />
                  <div style={{ color: '#999', fontSize: 12 }}>
                    照当前速度本月约 {projectMonthEnd(m.used).toLocaleString()}
                  </div>
                </Col>
              );
            })}
          </Row>
        )}
      </Card>

      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24} lg={14}>
          <Card title="近 30 天 · 新增用户与 DAU" size="small">
            <ReactECharts option={trendOption} style={{ height: 280 }} />
          </Card>
        </Col>
        <Col xs={24} lg={10}>
          <Card title="近 30 天 · 登录趋势" size="small">
            <ReactECharts option={loginOption} style={{ height: 280 }} />
          </Card>
        </Col>
      </Row>

      <Row gutter={[16, 16]} style={{ marginTop: 16 }}>
        <Col xs={24} md={12} lg={8}>
          <Card title="留存率（%，近 30 天注册用户）" size="small">
            <ReactECharts option={hbarOption(retentionData, ORANGE)} style={{ height: 160 }} />
          </Card>
        </Col>
        <Col xs={24} md={12} lg={8}>
          <Card title="用户活跃分布" size="small">
            <ReactECharts option={hbarOption(bucketsData)} style={{ height: 200 }} />
          </Card>
        </Col>
        <Col xs={24} md={12} lg={8}>
          <Card title="功能热度 Top（近 7 天）" size="small">
            {topEvents.length === 0 ? (
              <div style={{ color: '#999', padding: 24, textAlign: 'center' }}>暂无埋点数据</div>
            ) : (
              <ReactECharts option={hbarOption(topEvents)} style={{ height: Math.max(160, topEvents.length * 32) }} />
            )}
          </Card>
        </Col>
        <Col xs={24} md={12} lg={12}>
          <Card title="心愿热度 Top10" size="small">
            {topWishes.length === 0 ? (
              <div style={{ color: '#999', padding: 24, textAlign: 'center' }}>暂无数据</div>
            ) : (
              <ReactECharts
                option={hbarOption(topWishes.map((w) => [w.title, w.count]))}
                style={{ height: Math.max(160, topWishes.length * 32) }}
              />
            )}
          </Card>
        </Col>
        <Col xs={24} md={12} lg={12}>
          <Card title="景点打卡 Top10" size="small">
            {topPlaces.length === 0 ? (
              <div style={{ color: '#999', padding: 24, textAlign: 'center' }}>暂无数据</div>
            ) : (
              <ReactECharts
                option={hbarOption(topPlaces.map((p) => [p.place, p.count]), ORANGE)}
                style={{ height: Math.max(160, topPlaces.length * 32) }}
              />
            )}
          </Card>
        </Col>
      </Row>
    </div>
  );
}
