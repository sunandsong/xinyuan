import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../data.dart';
import '../notify.dart';
import '../pages/login_page.dart';
import '../share_poster.dart';
import '../sheets.dart';
import '../theme.dart';
import '../ui.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});
  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab>
    with SingleTickerProviderStateMixin {
  DateTime selected = dOnly(DateTime.now());
  late DateTime anchor = DateTime(selected.year, selected.month, 1);
  bool expanded = false; // false = 周视图, true = 月视图展开

  /// 0=周视图 1=月视图；拖动时直接跟手指走，松手再吸附到 0/1
  late final AnimationController _cal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  // 日历各部分的固定高度，跟手拖动要按像素算进度
  static const _headerH = 20.0, _gapH = 4.0, _cellH = 56.0;
  double get _weekH => _headerH + _gapH + _cellH;
  double get _monthH {
    final a = DateTime(selected.year, selected.month, 1);
    final rows =
        ((a.weekday % 7 + DateUtils.getDaysInMonth(a.year, a.month)) / 7)
            .ceil();
    return _headerH + _gapH + rows * _cellH;
  }

  @override
  void dispose() {
    _cal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(context),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 14, 13, 0),
            child: _dayList(),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  // ---------- 渐变 header（含日历）----------
  Widget _header(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B84DB), Color(0xFF4FA394), Color(0xFF5EB87C)],
          stops: [0, .55, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x333EA983),
              blurRadius: 20,
              offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          _topbar(),
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: _onSwipe,
            // 跟手：拖多少露多少，不是松手才一次性弹开
            onVerticalDragUpdate: (d) =>
                _cal.value += d.delta.dy / (_monthH - _weekH),
            onVerticalDragEnd: _snapCal,
            child: AnimatedBuilder(
              animation: _cal,
              builder: (context, _) {
                final t = _cal.value;
                final monthH = _monthH;
                return SizedBox(
                  height: _weekH + (monthH - _weekH) * t,
                  child: ClipRect(
                    child: Stack(children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: monthH,
                        child: IgnorePointer(
                          ignoring: t < .5,
                          child: Opacity(opacity: t, child: _monthGrid()),
                        ),
                      ),
                      if (t < .999)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: _weekH,
                          child: IgnorePointer(
                            ignoring: t >= .5,
                            child: Opacity(
                              // 周视图先淡出，别和月视图糊在一起
                              opacity: (1 - t * 2).clamp(0.0, 1.0),
                              child: _weekStrip(),
                            ),
                          ),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 顶栏 ----------
  Widget _topbar() {
    final base = expanded ? DateTime(selected.year, selected.month) : selected;
    final title = '${base.month}月';
    return Row(
      children: [
        GestureDetector(
          onTap: () => AppData.I.signedIn
              ? showNewTaskSheet(context, selected)
              : showBlurDialog(context, const LoginForm()),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add, size: 20, color: Colors.white),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _arrow(Icons.chevron_left_rounded, () => _shiftMonth(-1)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickMonth,
                child: SizedBox(
                  width: 66,
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
              _arrow(Icons.chevron_right_rounded, () => _shiftMonth(1)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => _MonthReportPage(
                    month: DateTime(selected.year, selected.month))),
          ),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.ios_share_rounded,
                size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 26, color: Colors.white.withValues(alpha: .85)),
      ),
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      selected = DateTime(
          selected.year, selected.month + delta, selected.day.clamp(1, 28));
      anchor = DateTime(selected.year, selected.month, 1);
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MonthPicker(initial: selected),
    );
    if (picked != null) {
      setState(() {
        selected = DateTime(picked.year, picked.month,
            selected.day.clamp(1, DateUtils.getDaysInMonth(picked.year, picked.month)));
        anchor = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  // ---------- 月视图（展开）----------
  Widget _monthGrid() {
    final monthAnchor = DateTime(selected.year, selected.month, 1);
    final lead = monthAnchor.weekday % 7; // 周日起
    final start = monthAnchor.subtract(Duration(days: lead));
    final rows = ((lead + DateUtils.getDaysInMonth(
                    monthAnchor.year, monthAnchor.month)) /
            7)
        .ceil();
    return Column(
      key: const ValueKey('month'),
      children: [
        _weekHeader(),
        const SizedBox(height: _gapH),
        for (var r = 0; r < rows; r++)
          Row(children: [
            for (var c = 0; c < 7; c++)
              Expanded(
                  child: _calCell(start.add(Duration(days: r * 7 + c)),
                      inMonth: start
                              .add(Duration(days: r * 7 + c))
                              .month ==
                          selected.month)),
          ]),
      ],
    );
  }

  Widget _weekHeader() {
    // 高度固定成 _headerH：跟手展开的像素账要按它算
    return SizedBox(
      height: _headerH,
      child: Row(children: [
        for (final w in weekNames)
          Expanded(
            child: Center(
              child: Text(w,
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: .6))),
            ),
          ),
      ]),
    );
  }

  // 蓝底上的日历格子（白色系）
  Widget _calCell(DateTime d, {required bool inMonth}) {
    final isToday = sameDay(d, dOnly(DateTime.now()));
    final isSel = sameDay(d, selected);
    final dot = AppData.I.dotOn(d);
    final hol = holidays['${d.month}-${d.day}'];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => selected = dOnly(d)),
      child: SizedBox(
        height: 56,
        child: Column(
          children: [
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 33,
              height: 33,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel
                    ? Colors.white
                    : (isToday
                        ? Colors.white.withValues(alpha: .22)
                        : Colors.transparent),
              ),
              child: Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      (isSel || isToday) ? FontWeight.w600 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isSel
                      ? T.accent
                      : inMonth
                          ? Colors.white
                          : Colors.white.withValues(alpha: .4),
                ),
              ),
            ),
            if (hol != null)
              Text(hol,
                  style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.white.withValues(alpha: inMonth ? .7 : .35)))
            else if (dot != null && !isSel)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .85),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- 周视图（默认）----------
  Widget _weekStrip() {
    final start = selected.subtract(Duration(days: selected.weekday % 7));
    return Column(
      key: const ValueKey('week'),
      children: [
        _weekHeader(),
        const SizedBox(height: _gapH), // 和月视图同一个间距，跟手切换时不跳
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
                child: _calCell(start.add(Duration(days: i)), inMonth: true)),
        ]),
      ],
    );
  }

  // ---------- 当天任务列表 ----------
  Widget _dayList() {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final all = AppData.I.tasksOn(selected);
        final active = all.where((t) => !t.done).toList();
        final done = all.where((t) => t.done).toList();
        final today = sameDay(selected, dOnly(DateTime.now()));
        final label =
            today ? '今天' : '${md(selected)} · ${weekLabel(selected)}';
        return SheetCard(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
          child: all.isEmpty
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text('这天还没有安排',
                            style: TextStyle(fontSize: 15, color: T.faint)),
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    for (var k = 0; k < active.length; k++)
                      StaggerIn(index: k, child: _taskRow(active[k])),
                    if (done.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 8, 14, 2),
                        child: Text('已完成',
                            style: TextStyle(fontSize: 15, color: T.faint)),
                      ),
                      for (final t in done) _taskRow(t),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
        );
      },
    );
  }

  Widget _taskRow(Task t) {
    final color = AppData.I.taskColor(t);
    return Slidable(
      key: ValueKey(t.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: .28,
        children: [
          CustomSlidableAction(
            onPressed: (_) => _changeTaskDate(t),
            backgroundColor: T.accent,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.zero,
            child: const Center(
                child: Icon(Icons.event_rounded, color: Colors.white)),
          ),
          CustomSlidableAction(
            onPressed: (_) => _confirmDeleteTask(t),
            backgroundColor: const Color(0xFFE05A5A),
            padding: EdgeInsets.zero,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            child: const Center(
                child: Icon(Icons.delete_outline_rounded, color: Colors.white)),
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showEditTaskPage(context, t),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          child: Row(
            children: [
              Cb(
                done: t.done,
                greyWhenDone: t.wishId == null,
                burstColor: color,
                onTap: () {
                  AppData.I.toggleTask(t);
                  // 勾完就不用再提醒了；取消勾选且还没到点的话再排回去
                  if (t.remind) {
                    t.done ? cancelTaskReminder(t) : scheduleTaskReminder(t);
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    fontFamily: 'MiSans',
                    fontSize: 18,
                    color: t.done ? T.faint : T.ink,
                    decoration: t.done ? TextDecoration.lineThrough : null,
                    decorationColor: T.faint,
                  ),
                  child: Text(t.title),
                ),
              ),
              WDot(t.done ? T.greyBar : color, glow: !t.done),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeTaskDate(Task t) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: t.day,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked == null) return;
    t.day = dOnly(picked);
    AppData.I.updateTask(t);
    if (t.remind) scheduleTaskReminder(t); // 日期变了，提醒要跟着挪到新的一天
  }

  void _confirmDeleteTask(Task t) {
    showConfirmDialog(
      context,
      emoji: '🗑️',
      title: '删除这个任务？',
      body: '「${t.title}」\n删除后无法恢复',
      onConfirm: () {
        if (t.remind) cancelTaskReminder(t);
        AppData.I.deleteTask(t);
      },
    );
  }

  // 左右滑：周视图换周，月视图换月
  void _onSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 80) return;
    setState(() {
      if (expanded) {
        final delta = v < 0 ? 1 : -1;
        selected = DateTime(selected.year, selected.month + delta,
            selected.day.clamp(1, 28));
        anchor = DateTime(selected.year, selected.month, 1);
      } else {
        selected = selected.add(Duration(days: v < 0 ? 7 : -7));
      }
    });
  }

  // 上下滑：展开 / 收起
  /// 松手吸附：快甩看方向，慢放看过没过半
  void _snapCal(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final open = v > 250 || (v > -250 && _cal.value > .5);
    setState(() => expanded = open);
    _cal.animateTo(open ? 1 : 0, curve: Curves.easeOutCubic);
  }
}

/// 成绩单：月度 / 年度 / 总计的完成任务统计 + 一键复制文字去显摆
class _MonthReportPage extends StatefulWidget {
  const _MonthReportPage({required this.month});
  final DateTime month; // 当月 1 号

  @override
  State<_MonthReportPage> createState() => _MonthReportPageState();
}

class _MonthReportPageState extends State<_MonthReportPage> {
  int scope = 0; // 0 = 月度, 1 = 年度, 2 = 总计

  String _dayLabel(Task t) => switch (scope) {
        0 => '${t.day.day}日',
        1 => md(t.day),
        _ => ymdDots(t.day),
      };

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
          child: ListenableBuilder(
            listenable: AppData.I,
            builder: (context, _) {
              final done = AppData.I.tasks
                  .where((t) =>
                      t.done &&
                      (scope == 2 || t.day.year == month.year) &&
                      (scope != 0 || t.day.month == month.month))
                  .toList()
                ..sort((a, b) => a.day.compareTo(b.day));
              final days = done.map((t) => dOnly(t.day)).toSet().length;
              final wishCount =
                  done.map((t) => t.wishId).whereType<String>().toSet().length;
              final period = [
                '${month.month}月',
                '${month.year}年',
                '到现在'
              ][scope];
              final bigLabel = [
                '${month.year}.${month.month}',
                '${month.year}',
                '总计'
              ][scope];
              return Column(
                children: [
                  Row(
                    children: [
                      PillBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.pop(context)),
                      const Expanded(
                        child: Center(
                          child: Text('人生清单',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 38),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final (i, label)
                          in const [(0, '月度'), (1, '年度'), (2, '总计')])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SelChip(
                              label: label,
                              selected: scope == i,
                              onTap: () => setState(() => scope = i)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SheetCard(
                      padding: const EdgeInsets.all(18),
                      child: done.isEmpty
                          ? Center(
                              child: Text('$period还没有完成的任务',
                                  style: const TextStyle(
                                      fontSize: 15, color: T.faint)),
                            )
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                Text(bigLabel,
                                    style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1,
                                        color: T.accent,
                                        height: 1)),
                                const SizedBox(height: 10),
                                Text('$period你${scope == 2 ? '一共' : ''}完成了\n${done.length} 个任务',
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600,
                                        height: 1.5)),
                                const SizedBox(height: 14),
                                _stat('打卡天数', '$days 天'),
                                if (wishCount > 0)
                                  _stat('推进的心愿', '$wishCount 个'),
                                const SizedBox(height: 10),
                                for (final t in done)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    child: Row(
                                      children: [
                                        WDot(AppData.I.taskColor(t),
                                            glow: false),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(t.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                        ),
                                        Text(_dayLabel(t),
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: T.faint,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures()
                                                ])),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  BigBtn('分享',
                      onTap: () =>
                          _showPoster(done, days, wishCount, period)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showPoster(
      List<Task> done, int days, int wishCount, String period) {
    final bigLabel = [
      '${widget.month.year}.${widget.month.month}',
      '${widget.month.year}',
      '总计'
    ][scope];
    showPosterShare(
      context,
      subtitle: '人生清单 · $bigLabel成绩单',
      summary: '$period我${scope == 2 ? '一共' : ''}完成了 ${done.length} 个任务',
      stats: [
        ('完成任务', '${done.length}'),
        ('打卡天数', '$days'),
        if (wishCount > 0) ('推进心愿', '$wishCount'),
      ],
    );
  }

  Widget _stat(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: T.field))),
      child: Row(
        children: [
          Text(k, style: const TextStyle(fontSize: 15, color: T.muted)),
          const Spacer(),
          Text(v,
              style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}
/// 年月选择器（底部弹层）
class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.initial});
  final DateTime initial;
  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: const BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDEDFE5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 年份切换
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => year--),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.chevron_left_rounded,
                      size: 26, color: T.muted),
                ),
              ),
              SizedBox(
                width: 96,
                child: Text('$year 年',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => year++),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 26, color: T.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 12 个月
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var m = 1; m <= 12; m++)
                _monthCell(m,
                    isSel: year == widget.initial.year &&
                        m == widget.initial.month,
                    isCurrent: year == now.year && m == now.month),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthCell(int m, {required bool isSel, required bool isCurrent}) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, DateTime(year, m)),
      child: Container(
        decoration: BoxDecoration(
          color: isSel ? T.accent : T.field,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text('$m 月',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight:
                  (isSel || isCurrent) ? FontWeight.w600 : FontWeight.w400,
              color: isSel
                  ? Colors.white
                  : (isCurrent ? T.accent : T.ink),
            )),
      ),
    );
  }
}
