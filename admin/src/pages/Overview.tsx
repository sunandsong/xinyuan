import { useEffect, useState, type ReactNode } from 'react';
import { Alert, Button, Card, Col, Progress, Row, Skeleton, message } from 'antd';
import {
  DownloadOutlined,
  TeamOutlined,
  FireOutlined,
  StarOutlined,
  CheckCircleOutlined,
  CheckSquareOutlined,
  MailOutlined,
  MessageOutlined,
  PlusOutlined,
  CheckOutlined,
  TrophyOutlined,
} from '@ant-design/icons';
import ReactECharts from 'echarts-for-react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import { barOption, hbarOption, trendOption } from '../charts';
import EmptyState from '../components/EmptyState';
import SectionTitle from '../components/SectionTitle';
import { projectMetricEnd, projectQuota } from '../quotaUtils';
import {
  ACCENT,
  CARD_STYLE,
  CHART_BLUE,
  CHART_ORANGE,
  INK,
  LINE,
  MUTED,
  NEUTRAL,
  NEUTRAL_SOFT,
  TILE_COLORS,
  WARN,
} from '../theme';

const ROW_A_HEIGHT = 220;
const ROW_B_HEIGHT = 320;

interface Stats {
  totals: {
    users: number;
    weekActive: number;
    weekRegistered: number;
    weekCreatedTasks: number;
    weekCompletedTasks: number;
    weekCompletedWishes: number;
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
  package?: { id: string; name?: string } | null;
  summary?: {
    limit: number;
    used: number;
    unit: string;
    packageId?: string;
    packageName?: string;
  } | null;
  metrics?: Record<string, { used: number | null; limit: number | null; points?: number | null }>;
}

const QUOTA_LABELS: Record<string, string> = {
  dbRead: '数据库读（次/月）',
  dbWrite: '数据库写（次/月）',
  functionInvoke: '函数调用（次/月）',
  storage: '云存储容量（MB）',
};

const METRIC_UNITS: Record<string, string> = {
  dbRead: '次',
  dbWrite: '次',
  functionInvoke: '次',
  storage: 'MB',
};

function StatTile({
  icon,
  label,
  value,
  fg = ACCENT,
  bg = '#E2F1EA',
  warn = false,
  onClick,
}: {
  icon: ReactNode;
  label: string;
  value: number;
  fg?: string;
  bg?: string;
  warn?: boolean;
  onClick?: () => void;
}) {
  return (
    <div
      role={onClick ? 'button' : undefined}
      onClick={onClick}
      style={{
        ...CARD_STYLE,
        background: '#fff',
        padding: '16px 18px',
        height: '100%',
        cursor: onClick ? 'pointer' : undefined,
        borderLeft: warn ? `3px solid ${WARN}` : undefined,
        transition: 'box-shadow .15s ease',
      }}
      onMouseEnter={(e) => {
        if (onClick) e.currentTarget.style.boxShadow = '0 2px 8px rgba(16,24,40,.08)';
      }}
      onMouseLeave={(e) => {
        if (onClick) e.currentTarget.style.boxShadow = CARD_STYLE.boxShadow as string;
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
        <div
          style={{
            width: 30,
            height: 30,
            borderRadius: 9,
            background: warn ? '#FFF1E0' : bg,
            color: warn ? WARN : fg,
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
      <div className="tabular-nums" style={{ fontSize: 26, fontWeight: 700, color: INK, lineHeight: 1.2 }}>
        {value.toLocaleString()}
      </div>
    </div>
  );
}

export default function Overview() {
  const navigate = useNavigate();
  const [stats, setStats] = useState<Stats | null>(null);
  const [quota, setQuota] = useState<Quota | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);

  useEffect(() => {
    api
      .get('/admin/stats')
      .then(setStats)
      .catch((e) => setError(String(e.message ?? e)));
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
  if (!stats) {
    return (
      <div style={{ padding: '20px 24px 32px' }}>
        <Skeleton active paragraph={{ rows: 2 }} style={{ marginBottom: 24 }} />
        <Row gutter={[16, 16]}>
          {Array.from({ length: 7 }).map((_, i) => (
            <Col key={i} xs={12} sm={8} md={6} lg={24 / 7}>
              <Skeleton.Input active block style={{ height: 88 }} />
            </Col>
          ))}
        </Row>
      </div>
    );
  }

  const { totals, series, retention, topEvents, topWishes, topPlaces, activeBuckets } = stats;

  const statTiles: Array<{
    icon: ReactNode;
    label: string;
    value: number;
    colors?: { fg: string; bg: string };
    warn?: boolean;
    onClick?: () => void;
  }> = [
    { icon: <TeamOutlined />, label: '注册用户', value: totals.users, colors: TILE_COLORS[0], onClick: () => navigate('/users') },
    { icon: <StarOutlined />, label: '心愿总数', value: totals.wishes, colors: TILE_COLORS[2], onClick: () => navigate('/wishes') },
    { icon: <CheckCircleOutlined />, label: '已实现心愿', value: totals.doneWishes, colors: TILE_COLORS[3] },
    { icon: <CheckSquareOutlined />, label: '任务总数', value: totals.tasks, colors: TILE_COLORS[4], onClick: () => navigate('/tasks') },
    { icon: <MailOutlined />, label: '时光胶囊', value: totals.letters, colors: TILE_COLORS[5], onClick: () => navigate('/capsules') },
    {
      icon: <MessageOutlined />,
      label: '待处理反馈',
      value: totals.feedbackOpen,
      colors: { fg: NEUTRAL, bg: NEUTRAL_SOFT },
      warn: totals.feedbackOpen > 0,
      onClick: () => navigate('/feedback'),
    },
  ];

  const days = series.signups.map(([d]) => d.slice(5));

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
    <div style={{ height: 'calc(100vh - 56px)', overflowY: 'auto' }}>
    <div style={{ padding: '20px 24px 32px' }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'flex-end',
          justifyContent: 'space-between',
          marginBottom: 4,
          gap: 16,
          flexWrap: 'wrap',
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
        >
          导出全库备份
        </Button>
      </div>

      <SectionTitle>本周动态</SectionTitle>
      <Row gutter={16} wrap={false} style={{ marginBottom: 24 }}>
        {[
          {
            icon: <FireOutlined />,
            label: '本周活跃',
            value: totals.weekActive,
            colors: TILE_COLORS[1],
          },
          {
            icon: <TeamOutlined />,
            label: '本周注册',
            value: totals.weekRegistered,
            colors: TILE_COLORS[0],
            onClick: () => navigate('/users'),
          },
          {
            icon: <PlusOutlined />,
            label: '本周创建任务',
            value: totals.weekCreatedTasks,
            colors: TILE_COLORS[0],
            onClick: () => navigate('/tasks'),
          },
          {
            icon: <CheckOutlined />,
            label: '本周完成任务',
            value: totals.weekCompletedTasks,
            colors: TILE_COLORS[4],
            onClick: () => navigate('/tasks'),
          },
          {
            icon: <TrophyOutlined />,
            label: '本周完成心愿',
            value: totals.weekCompletedWishes,
            colors: TILE_COLORS[3],
            onClick: () => navigate('/wishes'),
          },
        ].map(({ icon, label, value, colors, onClick }) => (
          <Col key={label} flex="1" style={{ minWidth: 0 }}>
            <StatTile icon={icon} label={label} value={value} fg={colors.fg} bg={colors.bg} onClick={onClick} />
          </Col>
        ))}
      </Row>

      <SectionTitle>核心指标</SectionTitle>
      <Row gutter={[16, 16]}>
        {statTiles.map(({ icon, label, value, colors, warn, onClick }) => (
          <Col key={label} xs={12} sm={8} md={6} lg={4}>
            <StatTile
              icon={icon}
              label={label}
              value={value}
              fg={colors?.fg}
              bg={colors?.bg}
              warn={warn}
              onClick={onClick}
            />
          </Col>
        ))}
      </Row>

      <SectionTitle>本月资源用量</SectionTitle>
      <Card size="small" variant="borderless" style={CARD_STYLE}>
        {!quota ? (
          <Skeleton active paragraph={{ rows: 2 }} />
        ) : !quota.available ? (
          <span style={{ color: MUTED }}>
            未配置腾讯云密钥（TC_SECRET_ID/TC_SECRET_KEY），配置后可看数据库/函数/存储用量
          </span>
        ) : (
          <>
            {quota.summary && (() => {
              const { limit, used, unit, packageName } = quota.summary;
              const pct = Math.min(100, Math.round((used / limit) * 100));
              const forecast = projectQuota(used, limit);
              const barColor =
                forecast.status === 'exceeded' || pct >= 90
                  ? undefined
                  : pct >= 70
                    ? CHART_ORANGE
                    : CHART_BLUE;
              return (
                <div
                  style={{
                    marginBottom: 20,
                    paddingBottom: 20,
                    borderBottom: `1px solid ${LINE}`,
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                    <div>
                      <div style={{ color: MUTED, fontSize: 13, marginBottom: 4 }}>
                        本月资源点{packageName ? ` · ${packageName}` : ''}
                      </div>
                      <div className="tabular-nums" style={{ fontSize: 22, fontWeight: 700, color: INK }}>
                        已用 {used.toLocaleString()} / 共 {limit.toLocaleString()} {unit}
                      </div>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                      <div className="tabular-nums" style={{ fontSize: 20, fontWeight: 700, color: INK }}>
                        {pct}%
                      </div>
                      <div style={{ color: MUTED, fontSize: 12 }}>已消耗</div>
                    </div>
                  </div>
                  <Progress
                    percent={pct}
                    status={forecast.status === 'exceeded' || pct >= 90 ? 'exception' : undefined}
                    strokeColor={barColor}
                    style={{ margin: '12px 0 8px' }}
                  />
                  <div
                    style={{
                      fontSize: 13,
                      color:
                        forecast.status === 'exceeded' || forecast.status === 'warn'
                          ? WARN
                          : MUTED,
                    }}
                  >
                    {forecast.message}
                  </div>
                </div>
              );
            })()}
            <Row gutter={[24, 16]}>
              {Object.entries(quota.metrics ?? {}).map(([key, m]) => {
                const label = QUOTA_LABELS[key] ?? key;
                const unit = METRIC_UNITS[key] ?? '';
                if (m.used == null)
                  return (
                    <Col key={key} xs={24} sm={12} lg={6}>
                      <div style={{ color: MUTED, fontSize: 13, marginBottom: 4 }}>{label}</div>
                      <div className="tabular-nums" style={{ fontSize: 20, fontWeight: 700, color: INK }}>—</div>
                    </Col>
                  );
                const projected = projectMetricEnd(m.used);
                return (
                  <Col key={key} xs={24} sm={12} lg={6}>
                    <div style={{ color: MUTED, fontSize: 13, marginBottom: 6 }}>{label}</div>
                    {m.limit ? (
                      <>
                        <Progress
                          percent={Math.min(100, Math.round((m.used / m.limit) * 100))}
                          size="small"
                          strokeColor={CHART_BLUE}
                        />
                        <div className="tabular-nums" style={{ color: INK, fontSize: 13, marginTop: 4 }}>
                          已用 {m.used.toLocaleString()} / 共 {m.limit.toLocaleString()} {unit}
                        </div>
                      </>
                    ) : (
                      <div className="tabular-nums" style={{ fontSize: 20, fontWeight: 700, color: INK }}>
                        {m.used.toLocaleString()} {unit}
                      </div>
                    )}
                    {m.points != null && m.points > 0 && (
                      <div style={{ color: MUTED, fontSize: 12, marginTop: 4 }}>
                        约合 {m.points.toLocaleString()} 资源点
                      </div>
                    )}
                    <div style={{ color: MUTED, fontSize: 12, marginTop: 2 }}>
                      按当前速度月末约 {projected.toLocaleString()} {unit}
                    </div>
                  </Col>
                );
              })}
            </Row>
          </>
        )}
      </Card>

      <SectionTitle>增长趋势</SectionTitle>
      <Row gutter={[16, 16]}>
        <Col xs={24} lg={14}>
          <Card title="近 30 天 · 新增用户与 DAU" size="small" variant="borderless" style={CARD_STYLE}>
            <ReactECharts
              option={trendOption(
                days,
                series.signups.map(([, v]) => v),
                series.dau.map(([, v]) => v),
              )}
              style={{ height: 280 }}
            />
          </Card>
        </Col>
        <Col xs={24} lg={10}>
          <Card title="近 30 天 · 登录趋势" size="small" variant="borderless" style={CARD_STYLE}>
            <ReactECharts
              option={barOption(days, series.logins.map(([, v]) => v))}
              style={{ height: 280 }}
            />
          </Card>
        </Col>
      </Row>

      <SectionTitle>热度与分布</SectionTitle>
      <Row gutter={[16, 16]}>
        <Col xs={24} md={12} lg={8}>
          <Card title="留存率（%，近 30 天注册用户）" size="small" variant="borderless" style={CARD_STYLE}>
            <ReactECharts option={hbarOption(retentionData, CHART_ORANGE)} style={{ height: ROW_A_HEIGHT }} />
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
              <EmptyState height={ROW_A_HEIGHT}>暂无埋点数据</EmptyState>
            ) : (
              <ReactECharts option={hbarOption(topEvents)} style={{ height: ROW_A_HEIGHT }} />
            )}
          </Card>
        </Col>
        <Col xs={24} md={12} lg={12}>
          <Card title="心愿热度 Top10" size="small" variant="borderless" style={CARD_STYLE}>
            {topWishes.length === 0 ? (
              <EmptyState height={ROW_B_HEIGHT}>暂无数据</EmptyState>
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
              <EmptyState height={ROW_B_HEIGHT}>暂无数据</EmptyState>
            ) : (
              <ReactECharts
                option={hbarOption(topPlaces.map((p) => [p.place, p.count]), CHART_ORANGE)}
                style={{ height: ROW_B_HEIGHT }}
              />
            )}
          </Card>
        </Col>
      </Row>
    </div>
    </div>
  );
}
