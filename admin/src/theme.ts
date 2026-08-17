import type { CSSProperties } from 'react';
import type { ThemeConfig } from 'antd';

/** 跟 App 端 frontend/lib/theme.dart 的 T.* 对齐 */
export const INK = '#1C1C21';
export const MUTED = '#8A8C98';
export const FAINT = '#A2A4AE';
export const LINE = '#E6E7EC';
export const BG = '#F2F3F7';
export const CARD = '#FFFFFF';
export const ACCENT = '#3EA983';
export const ACCENT_SOFT = '#E2F1EA';
export const WARN = '#fa8c16';
export const WARN_SOFT = '#FFF1E0';
export const NEUTRAL = '#8A8C98';
export const NEUTRAL_SOFT = '#EEEFF2';
export const DANGER = '#E05A5A';

export const GRADIENT = 'linear-gradient(135deg, #4B84DB 0%, #5EB87C 100%)';

export const CARD_STYLE: CSSProperties = {
  borderRadius: 14,
  boxShadow: '0 1px 2px rgba(16,24,40,.04), 0 1px 8px rgba(16,24,40,.03)',
};

/** ECharts 双系列色 */
export const CHART_BLUE = ACCENT;
export const CHART_ORANGE = WARN;

/** 统计卡图标身份色（跳过 slot2 橙——橙留给状态色） */
export const TILE_COLORS: Array<{ fg: string; bg: string }> = [
  { fg: '#2A78D6', bg: '#E8F1FB' },
  { fg: ACCENT, bg: ACCENT_SOFT },
  { fg: '#EDA100', bg: '#FDF1DC' },
  { fg: '#E87BA4', bg: '#FCE9F0' },
  { fg: '#008300', bg: '#E3F1E3' },
  { fg: '#4A3AA7', bg: '#EAE7F8' },
];

export const antdTheme: ThemeConfig = {
  token: {
    colorPrimary: ACCENT,
    colorBgLayout: BG,
    colorBgContainer: CARD,
    colorText: INK,
    colorTextSecondary: MUTED,
    colorBorder: LINE,
    colorBorderSecondary: LINE,
    borderRadius: 10,
    borderRadiusLG: 14,
    fontFamily: 'MiSans, "PingFang SC", -apple-system, sans-serif',
    boxShadow: '0 1px 2px rgba(16,24,40,.04), 0 1px 8px rgba(16,24,40,.03)',
    boxShadowSecondary: '0 1px 2px rgba(16,24,40,.04), 0 1px 8px rgba(16,24,40,.03)',
  },
  components: {
    Layout: {
      headerBg: CARD,
      siderBg: CARD,
      bodyBg: BG,
      headerHeight: 56,
    },
    Menu: {
      itemSelectedBg: ACCENT_SOFT,
      itemSelectedColor: ACCENT,
      itemHoverBg: '#F7F8FA',
      itemColor: MUTED,
      itemActiveBg: ACCENT_SOFT,
      iconSize: 16,
    },
    Table: {
      headerBg: '#FAFBFC',
      rowHoverBg: '#F7F8FA',
      borderColor: LINE,
    },
    Card: {
      borderRadiusLG: 14,
    },
    Button: {
      borderRadius: 8,
    },
    Input: {
      borderRadius: 10,
      paddingBlock: 10,
      paddingInline: 14,
      colorBgContainer: '#FAFBFC',
      activeBorderColor: ACCENT,
      hoverBorderColor: '#D5D7DE',
      activeShadow: '0 0 0 3px rgba(62,169,131,.12)',
    },
    Select: {
      borderRadius: 10,
      colorBgContainer: '#FAFBFC',
    },
    DatePicker: {
      borderRadius: 10,
      colorBgContainer: '#FAFBFC',
    },
    Modal: {
      borderRadiusLG: 16,
      paddingContentHorizontal: 24,
      titleFontSize: 17,
      titleLineHeight: 1.4,
    },
    Form: {
      labelFontSize: 13,
      labelColor: INK,
      itemMarginBottom: 16,
    },
  },
};

/** 路由 → 页面元信息（顶栏标题 + 面包屑） */
export const PAGE_META: Record<string, { title: string; parent?: string }> = {
  '/': { title: '数据总览' },
  '/users': { title: '用户' },
  '/feedback': { title: '反馈' },
  '/login-logs': { title: '登录日志' },
  '/events': { title: '行为事件' },
  '/wishes': { title: '心愿', parent: '数据表' },
  '/tasks': { title: '任务', parent: '数据表' },
  '/capsules': { title: '时光胶囊', parent: '数据表' },
  '/default-lists': { title: '默认清单', parent: '内容配置' },
  '/milestone-templates': { title: '里程碑模板', parent: '内容配置' },
  '/images': { title: '图片素材', parent: '内容配置' },
  '/honors': { title: '荣誉定义', parent: '内容配置' },
  '/attractions': { title: '景点库', parent: '内容配置' },
  '/blocked-words': { title: '屏蔽词', parent: '内容配置' },
  '/announcements': { title: '公告与版本', parent: '内容配置' },
  '/demo-users': { title: '演示用户', parent: '内容配置' },
  '/deletion-requests': { title: '注销申请' },
  '/audit-log': { title: '操作日志' },
};
