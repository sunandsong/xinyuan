/** 资源用量预估：按本月已用天数线性外推 */
export interface QuotaForecast {
  status: 'exceeded' | 'safe' | 'warn' | 'unknown';
  message: string;
  projectedEnd?: number;
}

export function projectQuota(used: number, limit: number): QuotaForecast {
  const now = new Date();
  const day = now.getDate();
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();

  if (limit <= 0) return { status: 'unknown', message: '暂无额度上限数据' };
  if (used >= limit) return { status: 'exceeded', message: '已超限，请尽快处理' };

  if (day <= 0 || used <= 0) {
    return { status: 'unknown', message: '本月用量太少，暂无法预估' };
  }

  const daily = used / day;
  const projectedEnd = Math.round(daily * daysInMonth);

  if (projectedEnd <= limit) {
    return {
      status: 'safe',
      message: `按当前速度本月不会超（月末约 ${projectedEnd.toLocaleString()}）`,
      projectedEnd,
    };
  }

  const daysUntil = (limit - used) / daily;
  const exceed = new Date(now);
  exceed.setDate(now.getDate() + Math.ceil(daysUntil));
  const dateStr = `${exceed.getMonth() + 1}月${exceed.getDate()}日`;
  return {
    status: 'warn',
    message: `按当前速度预计 ${dateStr} 耗尽`,
    projectedEnd,
  };
}

export function projectMetricEnd(used: number): number {
  const day = new Date().getDate();
  const daysInMonth = new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate();
  if (day <= 0) return used;
  return Math.round((used / day) * daysInMonth);
}
