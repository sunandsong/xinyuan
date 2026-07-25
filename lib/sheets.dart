import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'data.dart';
import 'pages/import_page.dart';
import 'theme.dart';
import 'ui.dart';

final _rand = math.Random();
Color _randomWishColor() =>
    T.wishPalette[_rand.nextInt(T.wishPalette.length)];

/// 新建任务（底部弹层）
Future<void> showNewTaskSheet(BuildContext context, DateTime day) =>
    showAppSheet(context, _NewTaskSheet(day: day));

class _NewTaskSheet extends StatefulWidget {
  const _NewTaskSheet({required this.day});
  final DateTime day;
  @override
  State<_NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends State<_NewTaskSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  late DateTime _day = widget.day;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: true,
          decoration: fieldDeco('想做什么…'),
          style: const TextStyle(fontSize: 18),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _desc,
          decoration: fieldDeco('描述（可选）'),
          style: const TextStyle(fontSize: 15),
          maxLines: 2,
          minLines: 1,
        ),
        const SizedBox(height: 14),
        // 日期行
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: T.field,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, size: 19, color: T.accent),
                const SizedBox(width: 9),
                Text('日期', style: const TextStyle(fontSize: 15)),
                const Spacer(),
                Text(_dateLabel(),
                    style: const TextStyle(
                        fontSize: 15,
                        color: T.accent,
                        fontWeight: FontWeight.w600)),
                const Icon(Icons.chevron_right, size: 18, color: T.faint),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        BigBtn('添加', onTap: _submit),
      ],
    );
  }

  String _dateLabel() {
    final today = dOnly(DateTime.now());
    if (sameDay(_day, today)) return '今天';
    if (sameDay(_day, today.add(const Duration(days: 1)))) return '明天';
    return md(_day);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _day = dOnly(picked));
  }

  void _submit() {
    final text = _title.text.trim();
    if (text.isEmpty) return;
    AppData.I.addTask(text, _day,
        color: _randomWishColor(),
        desc: _desc.text.trim().isEmpty ? null : _desc.text.trim());
    Navigator.pop(context);
  }
}

/// 新建心愿（底部弹层）
Future<void> showNewWishSheet(BuildContext context) =>
    showAppSheet(context, const _NewWishSheet());

class _NewWishSheet extends StatefulWidget {
  const _NewWishSheet();
  @override
  State<_NewWishSheet> createState() => _NewWishSheetState();
}

class _NewWishSheetState extends State<_NewWishSheet> {
  final _c = TextEditingController();
  final _desc = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 从人生清单批量导入
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ImportWishPage()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: T.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 17)),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text('不知道写什么？从人生必做清单挑',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: T.accent)),
                ),
                Icon(Icons.chevron_right,
                    size: 19, color: T.accent.withValues(alpha: .7)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _c,
          autofocus: true,
          decoration: fieldDeco('这辈子想做的一件事…'),
          style: const TextStyle(fontSize: 18),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _desc,
          decoration: fieldDeco('描述（可选）'),
          style: const TextStyle(fontSize: 15),
          maxLines: 3,
          minLines: 1,
        ),
        const SizedBox(height: 16),
        BigBtn('写进清单', onTap: _submit),
      ],
    );
  }

  void _submit() {
    final text = _c.text.trim();
    if (text.isEmpty) return;
    AppData.I.addWish(text, _randomWishColor(),
        desc: _desc.text.trim().isEmpty ? null : _desc.text.trim());
    Navigator.pop(context);
  }
}
