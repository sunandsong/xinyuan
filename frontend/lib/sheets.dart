import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'data.dart';
import 'pages/import_page.dart';
import 'theme.dart';
import 'ui.dart';

final _rand = math.Random();
Color _randomWishColor() => T.wishPalette[_rand.nextInt(T.wishPalette.length)];

/// 新建任务（底部弹层）
Future<void> showNewTaskSheet(BuildContext context, DateTime day) =>
    showAppSheet(context, _TaskForm(day: day));

/// 编辑已有任务（整页）
Future<void> showEditTaskPage(BuildContext context, Task task) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NewTaskPage(day: task.day, editing: task)),
    );

/// 新建/编辑任务（整页，新建任务时也可以从弹层点"展开"进来，带着已经填的内容）
class NewTaskPage extends StatefulWidget {
  const NewTaskPage({
    super.key,
    required this.day,
    this.initialTitle,
    this.initialDesc,
    this.editing,
  });
  final DateTime day;
  final String? initialTitle;
  final String? initialDesc;
  final Task? editing;
  @override
  State<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends State<NewTaskPage> {
  final _formKey = GlobalKey<_TaskFormState>();

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
          child: Column(
            children: [
              Row(
                children: [
                  PillBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        editing ? '编辑任务' : '新建任务',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _formKey.currentState?.submit(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        editing ? '保存' : '添加',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: T.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _TaskForm(
                  key: _formKey,
                  day: widget.day,
                  initialTitle: widget.initialTitle,
                  initialDesc: widget.initialDesc,
                  editing: widget.editing,
                  expandable: false,
                  asPage: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskForm extends StatefulWidget {
  const _TaskForm({
    super.key,
    required this.day,
    this.initialTitle,
    this.initialDesc,
    this.editing,
    this.expandable = true,
    this.asPage = false,
  });
  final DateTime day;
  final String? initialTitle;
  final String? initialDesc;
  final Task? editing;
  final bool expandable;
  final bool asPage;
  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late final _title =
      TextEditingController(text: widget.editing?.title ?? widget.initialTitle);
  late final _desc =
      TextEditingController(text: widget.editing?.desc ?? widget.initialDesc);
  late DateTime _day = widget.editing?.day ?? widget.day;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _expand() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewTaskPage(
          day: _day,
          initialTitle: _title.text,
          initialDesc: _desc.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asPage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: _fields()),
          ),
          const SizedBox(height: 12),
          _toolbarRow(showExpand: false, showSubmit: false),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._fields(),
        const SizedBox(height: 8),
        _toolbarRow(showExpand: widget.expandable, showSubmit: true),
      ],
    );
  }

  List<Widget> _fields() {
    return [
      TextField(
        controller: _title,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '准备做什么？',
          hintStyle: TextStyle(fontSize: 19, color: T.faint),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(fontSize: 19),
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _desc,
        decoration: const InputDecoration(
          hintText: '描述',
          hintStyle: TextStyle(fontSize: 14.5, color: T.faint),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(fontSize: 14.5),
        maxLines: widget.asPage ? null : 2,
        minLines: widget.asPage ? 5 : 1,
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _toolbarRow({required bool showExpand, required bool showSubmit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: T.field,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: T.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _dateLabel(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: T.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showExpand) ...[
            const SizedBox(width: 10),
            toolIconBtn(Icons.open_in_full_rounded, _expand),
          ],
          if (showSubmit) ...[
            const Spacer(),
            GestureDetector(
              onTap: submit,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: T.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
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

  void submit() {
    final text = _title.text.trim();
    if (text.isEmpty) return;
    final desc = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    final editing = widget.editing;
    if (editing != null) {
      editing.title = text;
      editing.day = _day;
      editing.desc = desc;
      AppData.I.updateTask(editing);
    } else {
      AppData.I.addTask(text, _day, color: _randomWishColor(), desc: desc);
    }
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImportWishPage()),
            );
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
                  child: Text(
                    '不知道写什么？从人生必做清单挑',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: T.accent,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 19,
                  color: T.accent.withValues(alpha: .7),
                ),
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
    AppData.I.addWish(
      text,
      _randomWishColor(),
      desc: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
    );
    Navigator.pop(context);
  }
}
