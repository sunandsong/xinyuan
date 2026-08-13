import { ACCENT, CHART_BLUE, CHART_ORANGE, LINE, MUTED } from './theme';

const tooltip = {
  trigger: 'axis' as const,
  backgroundColor: '#fff',
  borderColor: LINE,
  borderWidth: 1,
  textStyle: { color: MUTED, fontSize: 12 },
  extraCssText: 'border-radius:10px;box-shadow:0 4px 16px rgba(16,24,40,.08);',
};

const categoryAxis = {
  axisLine: { lineStyle: { color: LINE } },
  axisTick: { show: false },
  axisLabel: { color: MUTED },
};

const valueAxis = {
  minInterval: 1,
  splitLine: { lineStyle: { color: LINE } },
  axisLabel: { color: MUTED },
};

/** 横向条形图：类目倒序、圆角数据端 */
export function hbarOption(data: Array<[string, number]>, color = CHART_BLUE) {
  return {
    tooltip,
    grid: { left: 8, right: 40, top: 8, bottom: 8, containLabel: true },
    xAxis: {
      type: 'value' as const,
      ...valueAxis,
      axisLine: { show: false },
      axisTick: { show: false },
    },
    yAxis: {
      type: 'category' as const,
      data: data.map(([name]) => name),
      inverse: true,
      axisLabel: { width: 120, overflow: 'truncate' as const, color: MUTED },
      axisLine: { show: false },
      axisTick: { show: false },
    },
    series: [
      {
        type: 'bar' as const,
        data: data.map(([, v], i) => ({
          value: v,
          itemStyle: {
            color: i === 0 ? color : `${color}99`,
            borderRadius: [0, 4, 4, 0],
          },
        })),
        barMaxWidth: 18,
        label: { show: true, position: 'right' as const, color: MUTED },
      },
    ],
  };
}

/** 双折线 + 渐变面积 */
export function trendOption(
  days: string[],
  signups: number[],
  dau: number[],
) {
  return {
    color: [CHART_BLUE, CHART_ORANGE],
    tooltip,
    legend: { data: ['新增用户', 'DAU'], top: 0, textStyle: { color: MUTED } },
    grid: { left: 8, right: 16, top: 40, bottom: 8, containLabel: true },
    xAxis: { type: 'category' as const, data: days, ...categoryAxis },
    yAxis: { type: 'value' as const, ...valueAxis },
    series: [
      {
        name: '新增用户',
        type: 'line' as const,
        smooth: true,
        showSymbol: false,
        lineStyle: { width: 2 },
        areaStyle: {
          color: {
            type: 'linear' as const,
            x: 0, y: 0, x2: 0, y2: 1,
            colorStops: [
              { offset: 0, color: `${ACCENT}33` },
              { offset: 1, color: `${ACCENT}05` },
            ],
          },
        },
        data: signups,
      },
      {
        name: 'DAU',
        type: 'line' as const,
        smooth: true,
        showSymbol: false,
        lineStyle: { width: 2 },
        areaStyle: {
          color: {
            type: 'linear' as const,
            x: 0, y: 0, x2: 0, y2: 1,
            colorStops: [
              { offset: 0, color: `${CHART_ORANGE}33` },
              { offset: 1, color: `${CHART_ORANGE}05` },
            ],
          },
        },
        data: dau,
      },
    ],
  };
}

/** 柱状图：登录趋势 */
export function barOption(days: string[], values: number[], color = CHART_BLUE) {
  return {
    tooltip,
    grid: { left: 8, right: 16, top: 16, bottom: 8, containLabel: true },
    xAxis: { type: 'category' as const, data: days, ...categoryAxis },
    yAxis: { type: 'value' as const, ...valueAxis },
    series: [
      {
        name: '登录次数',
        type: 'bar' as const,
        data: values,
        itemStyle: { color, borderRadius: [4, 4, 0, 0] },
        barMaxWidth: 20,
      },
    ],
  };
}
