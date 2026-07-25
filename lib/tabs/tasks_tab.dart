import 'package:flutter/material.dart';
import '../data.dart';
import '../sheets.dart';
import '../theme.dart';
import '../ui.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});
  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  DateTime selected = dOnly(DateTime.now());
  late DateTime anchor = DateTime(selected.year, selected.month, 1);
  bool expanded = false; // false = 周视图, true = 月视图展开

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
          colors: [Color(0xFF6C8DFF), Color(0xFF4772FA), Color(0xFF3A5CE0)],
          stops: [0, .55, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x334772FA),
              blurRadius: 20,
              offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          _topbar(),
          const SizedBox(height: 14),
          GestureDetector(
            onHorizontalDragEnd: _onSwipe,
            onVerticalDragEnd: _onVerticalSwipe,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded ? _monthGrid() : _weekStrip(),
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
          onTap: () => showNewTaskSheet(context, selected),
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
        const SizedBox(height: 4),
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
    return Row(children: [
      for (final w in weekNames)
        Expanded(
          child: Center(
            child: Text(w,
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: .6))),
          ),
        ),
    ]);
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
        const SizedBox(height: 2),
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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: all.isEmpty
              ? Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
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
                    Text(label,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    for (var k = 0; k < active.length; k++)
                      StaggerIn(index: k, child: _taskRow(active[k])),
                    if (done.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 2),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Cb(
            done: t.done,
            greyWhenDone: t.wishId == null,
            burstColor: color,
            onTap: () => AppData.I.toggleTask(t),
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
  void _onVerticalSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 80) return;
    setState(() => expanded = v > 0);
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
