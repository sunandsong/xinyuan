import { useEffect, useState, type ReactNode } from 'react';
import { Alert, Button, Card, Col, Progress, Row, Spin, message } from 'antd';
import {
  DownloadOutlined,
  TeamOutlined,
  FireOutlined,
  StarOutlined,
  CheckCircleOutlined,
  CheckSquareOutlined,
  MailOutlined,
  MessageOutlined,
} from '@ant-design/icons';
import ReactECharts from 'echarts-for-react';
import { api } from '../api';

// 跟 App 端 theme.dart 的 T.* 同一套 token，管理端和 App 是一个产品，配色不该各画各的
const INK = '#1C1C21';
const MUTED = '#8A8C98';
const LINE = '#E6E7EC';
const ACCENT = '#3EA983';
const ACCENT_SOFT = '#E2F1EA';
const WARN = '#fa8c16';
const WARN_SOFT = '#FFF1E0';

// ECharts 双系列色：主色跟 App 端 T.accent 对齐，配色橙做对比。
// 已用 dataviz 六项检查校验：CVD 分离度、正常视觉区分度均 PASS；
// 对比度 WARN 已用可见直接标签（label:{show:true}）兜底。
const BLUE = ACCENT;
const ORANGE = WARN;

const CARD_STYLE = {
  borderRadius: 14,
  boxShadow: '0 1px 2px rgba(16,24,40,.04), 0 1px 8px rgba(16,24,40,.03)',
};

// 「热度与分布」两行图表各自的统一高度：同一行内不管条目数多少都用同一个高度，
// 图表内部留白比按条目数动态撑高、行内参差不齐好看
const ROW_A_HEIGHT = 220; // 留存率 / 用户活跃分布 / 功能热度 Top（这行都是 3-4 条数据）
const ROW_B_HEIGHT = 320; // 心愿热度 / 景点打卡 Top10（最多到 10 条）

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

/** 小标题：一条主题色短竖线 + 文字，用来分隔页面里的几个板块 */
function SectionTitle({ children }: { children: ReactNode }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '28px 0 12px' }}>
      <span style={{ width: 3, height: 14, borderRadius: 2, background: ACCENT }} />
      <span style={{ fontSize: 14, fontWeight: 600, color: INK }}>{children}</span>
    </div>
  );
}

/** 图表暂无数据时的占位——固定高度跟同行的真图表对齐，卡片高度不会跟着塌下去 */
function EmptyChart({ height, children }: { height: number; children: ReactNode }) {
  return (
    <div
      style={{
        height,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: MUTED,
      }}
    >
      {children}
    </div>
  );
}

/** 统计卡：图标徽标 + 灰色标签 + 大号数字。数字用 ink 而不是色块——
 * 色彩只在图标徽标上做身份标识，文字永远读 ink/muted（dataviz 规范）。 */
function StatTile({
  icon,
  label,
  value,
  warn = false,
}: {
  icon: ReactNode;
  label: string;
  value: number;
  warn?: boolean;
}) {
  return (
    <div style={{ ...CARD_STYLE, background: '#fff', padding: '16px 18px', height: '100%' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
        <div
          style={{
            width: 30,
            height: 30,
            borderRadius: 9,
            background: warn ? WARN_SOFT : ACCENT_SOFT,
            color: warn ? WARN : ACCENT,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 15,
            flexShrink: 0,
          }}
        >
          {icon}
        </div>
        <span style={{ color: MUTED, fontSize: 13 }}>{label}</span>
      </div>
      <div style={{ fontSize: 26, fontWeight: 700, color: INK, lineHeight: 1.2 }}>
        {value.toLocaleString()}
      </div>
    </div>
  );
}

/** 横向条形图：类目倒序（第一名在最上面）、4px 圆角数据端、纤细回缩网格线 */
function hbarOption(data: Array<[string, number]>, color = BLUE) {
  return {
    grid: { left: 8, right: 40, top: 8, bottom: 8, containLabel: true },
    xAxis: {
      type: 'value',
      minInterval: 1,
      splitLine: { lineStyle: { color: LINE } },
      axisLine: { show: false },
      axisTick: { show: false },
    },
    yAxis: {
      type: 'category',
      data: data.map(([name]) => name),
      inverse: true,
      axisLabel: { width: 120, overflow: 'truncate' as const, color: MUTED },
      axisLine: { show: false },
      axisTick: { show: false },
    },
    series: [
      {
        type: 'bar',
        data: data.map(([, v]) => v),
        itemStyle: { color, borderRadius: [0, 4, 4, 0] },
        barMaxWidth: 18,
        label: { show: true, position: 'right' as const, color: MUTED },
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

  const statTiles: Array<[ReactNode, string, number, boolean?]> = [
    [<TeamOutlined key="i" />, '注册用户', totals.users],
    [<FireOutlined key="i" />, '今日活跃', totals.todayActive],
    [<StarOutlined key="i" />, '心愿总数', totals.wishes],
    [<CheckCircleOutlined key="i" />, '已实现心愿', totals.doneWishes],
    [<CheckSquareOutlined key="i" />, '任务总数', totals.tasks],
    [<MailOutlined key="i" />, '时光胶囊', totals.letters],
    [<MessageOutlined key="i" />, '待处理反馈', totals.feedbackOpen, totals.feedbackOpen > 0],
  ];

  const days = series.signups.map(([d]) => d.slice(5)); // MM-DD 就够了，年份挤图

  const trendOption = {
    color: [BLUE, ORANGE],
    tooltip: { trigger: 'axis' as const },
    legend: { data: ['新增用户', 'DAU'], top: 0, textStyle: { color: MUTED } },
    grid: { left: 8, right: 44, top: 40, bottom: 8, containLabel: true },
    xAxis: {
      type: 'category' as const,
      data: days,
      axisLine: { lineStyle: { color: LINE } },
      axisTick: { show: false },
      axisLabel: { color: MUTED },
    },
    yAxis: {
      type: 'value' as const,
      minInterval: 1,
      splitLine: { lineStyle: { color: LINE } },
      axisLabel: { color: MUTED },
    },
    series: [
      {
        name: '新增用户',
        type: 'line' as const,
        smooth: true,
        showSymbol: false,
        lineStyle: { width: 2 },
        areaStyle: { opacity: 0.08 },
        endLabel: { show: true, formatter: '{c}', color: BLUE, fontWeight: 600 },
        data: series.signups.map(([, v]) => v),
      },
      {
        name: 'DAU',
        type: 'line' as const,
        smooth: true,
        showSymbol: false,
        lineStyle: { width: 2 },
        areaStyle: { opacity: 0.08 },
        endLabel: { show: true, formatter: '{c}', color: ORANGE, fontWeight: 600 },
        data: series.dau.map(([, v]) => v),
      },
    ],
  };

  const loginOption = {
    tooltip: { trigger: 'axis' as const },
    grid: { left: 8, right: 16, top: 16, bottom: 8, containLabel: true },
    xAxis: {
      type: 'category' as const,
      data: days,
      axisLine: { lineStyle: { color: LINE } },
      axisTick: { show: false },
      axisLabel: { color: MUTED },
    },
    yAxis: {
      type: 'value' as const,
      minInterval: 1,
      splitLine: { lineStyle: { color: LINE } },
      axisLabel: { color: MUTED },
    },
    series: [
      {
        name: '登录次数',
        type: 'bar' as const,
        data: series.logins.map(([, v]) => v),
        itemStyle: { color: BLUE, borderRadius: [4, 4, 0, 0] },
        barMaxWidth: 20,
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

  const today = new Date();

  return (
    <div style={{ padding: 24 }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'flex-end',
          justifyContent: 'space-between',
          marginBottom: 4,
        }}
      >
        <div>
          <div style={{ color: MUTED, fontSize: 13, marginBottom: 4 }}>
            {today.getFullYear()}年{today.getMonth() + 1}月{today.getDate()}日
          </div>
          <div style={{ fontSize: 22, fontWeight: 700, color: INK }}>数据总览</div>
        </div>
        <Button
          type="primary"
          icon={<DownloadOutlined />}
          loading={exporting}
          onClick={handleExport}
          style={{ borderRadius: 8 }}
        >
          导出全库备份
        </Button>
      </div>

      <SectionTitle>核心指标</SectionTitle>
      <Row gutter={[16, 16]}>
        {statTiles.map(([icon, label, value, warn]) => (
          <Col key={label} xs={12} sm={8} md={6} lg={24 / 7}>
            <StatTile icon={icon} label={label} value={value} warn={warn} />
          </Col>
        ))}
      </Row>

      <SectionTitle>本月资源用量</SectionTitle>
      <Card size="small" variant="borderless" style={CARD_STYLE}>
        {!quota ? (
          <Spin />
        ) : !quota.available ? (
          <span style={{ color: MUTED }}>
            未配置腾讯云密钥（TC_SECRET_ID/TC_SECRET_KEY），配置后可看数据库/函数/存储用量
          </span>
        ) : (
          <Row gutter={[24, 16]}>
            {Object.entries(quota.metrics ?? {}).map(([key, m]) => {
              const label = QUOTA_LABELS[key] ?? key;
              if (m.used == null)
                return (
                  <Col key={key} xs={24} sm={12} lg={6}>
                    <div style={{ color: MUTED, fontSize: 13, marginBottom: 4 }}>{label}</div>
                    <div style={{ fontSize: 20, fontWeight: 700, color: INK }}>—</div>
                  </Col>
                );
              // limit 拿得到才画进度条 + 70%/90% 预警；拿不到（目前恒 null）只显示用量和月底预估
              if (m.limit) {
                const pct = Math.round((m.used / m.limit) * 100);
                const status = pct >= 90 ? 'exception' : undefined;
                const color = pct >= 90 ? undefined : pct >= 70 ? ORANGE : BLUE;
                return (
                  <Col key={key} xs={24} sm={12} lg={6}>
                    <div style={{ color: MUTED, fontSize: 13, marginBottom: 6 }}>{label}</div>
                    <Progress percent={pct} status={status} strokeColor={color} />
                    <div style={{ color: MUTED, fontSize: 12 }}>
                      {m.used.toLocaleString()} / {m.limit.toLocaleString()}
                    </div>
                  </Col>
                );
              }
              return (
                <Col key={key} xs={24} sm={12} lg={6}>
                  <div style={{ color: MUTED, fontSize: 13, marginBottom: 4 }}>{label}</div>
                  <div style={{ fontSize: 20, fontWeight: 700, color: INK }}>
                    {m.used.toLocaleString()}
                  </div>
                  <div style={{ color: MUTED, fontSize: 12 }}>
                    照当前速度本月约 {projectMonthEnd(m.used).toLocaleString()}
                  </div>
                </Col>
              );
            })}
          </Row>
        )}
      </Card>

      <SectionTitle>增长趋势</SectionTitle>
      <Row gutter={[16, 16]}>
        <Col xs={24} lg={14}>
          <Card title="近 30 天 · 新增用户与 DAU" size="small" variant="borderless" style={CARD_STYLE}>
            <ReactECharts option={trendOption} style={{ height: 280 }} />
          </Card>
        </Col>
        <Col xs={24} lg={10}>
          <Card title="近 30 天 · 登录趋势" size="small" variant="borderless" style={CARD_STYLE}>
            <ReactECharts option={loginOption} style={{ height: 280 }} />
          </Card>
        </Col>
      </Row>

      <SectionTitle>热度与分布</SectionTitle>
      {/* 同一行内每张图统一高度——之前按条目数动态算高度，行内几张图参差不齐，
          一行三张、一行两张各自固定一个高度，图表内部留白比东拼西凑的卡片高度更耐看 */}
      <Row gutter={[16, 16]}>
        <Col xs={24} md={12} lg={8}>
          <Card title="留存率（%，近 30 天注册用户）" size="small" variant="borderless" style={CARD_STYLE}>
            <ReactECharts option={hbarOption(retentionData, ORANGE)} style={{ height: ROW_A_HEIGHT }} />
          </Card>
        </Col>
        <Col xs={24} md={12} lg={8}>
          <Card title="用户活跃分布" size="small" variant="borderless" style={CARD_STYLE}>
            <ReactECharts option={hbarOption(bucketsData)} style={{ height: ROW_A_HEIGHT }} />
          </Card>
        </Col>
        <Col xs={24} md={12} lg={8}>
          <Card title="功能热度 Top（近 7 天）" size="small" variant="borderless" style={CARD_STYLE}>
            {topEvents.length === 0 ? (
              <EmptyChart height={ROW_A_HEIGHT}>暂无埋点数据</EmptyChart>
            ) : (
              <ReactECharts option={hbarOption(topEvents)} style={{ height: ROW_A_HEIGHT }} />
            )}
          </Card>
        </Col>
        <Col xs={24} md={12} lg={12}>
          <Card title="心愿热度 Top10" size="small" variant="borderless" style={CARD_STYLE}>
            {topWishes.length === 0 ? (
              <EmptyChart height={ROW_B_HEIGHT}>暂无数据</EmptyChart>
            ) : (
              <ReactECharts
                option={hbarOption(topWishes.map((w) => [w.title, w.count]))}
                style={{ height: ROW_B_HEIGHT }}
              />
            )}
          </Card>
        </Col>
        <Col xs={24} md={12} lg={12}>
          <Card title="景点打卡 Top10" size="small" variant="borderless" style={CARD_STYLE}>
            {topPlaces.length === 0 ? (
              <EmptyChart height={ROW_B_HEIGHT}>暂无数据</EmptyChart>
            ) : (
              <ReactECharts
                option={hbarOption(topPlaces.map((p) => [p.place, p.count]), ORANGE)}
                style={{ height: ROW_B_HEIGHT }}
              />
            )}
          </Card>
        </Col>
      </Row>
    </div>
  );
}
