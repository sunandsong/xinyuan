import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'data.dart';
import 'pages/import_page.dart';
import 'theme.dart';
import 'ui.dart';

final _rand = math.Random();
Color _randomWishColor() => T.wishPalette[_rand.nextInt(T.wishPalette.length)];

/// 新建任务（底部弹层）；[wish] 非空时这个任务挂到该心愿名下，并继承心愿颜色
Future<void> showNewTaskSheet(BuildContext context, DateTime day,
        {Wish? wish}) =>
    showAppSheet(context, _TaskForm(day: day, wish: wish));

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
    this.wish,
  });
  final DateTime day;
  final String? initialTitle;
  final String? initialDesc;
  final Task? editing;
  final Wish? wish;
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
                  wish: widget.wish,
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
    this.wish,
    this.expandable = true,
    this.asPage = false,
  });
  final DateTime day;
  final String? initialTitle;
  final String? initialDesc;
  final Task? editing;
  final Wish? wish; // 归属心愿（从心愿详情页进来时带上）
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
          wish: widget.wish,
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
          if (widget.wish != null) ...[
            const SizedBox(width: 8),
            Flexible(child: _wishChip(widget.wish!)),
          ],
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

  /// 归属心愿的小胶囊（只展示，不可改；要换心愿就从对应心愿详情页新建）
  Widget _wishChip(Wish w) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: T.field,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WDot(w.color, size: 8),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              w.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                color: T.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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

  /// 铃铛胶囊：没开提醒时点一下选时间顺便打开；已经开着再点就直接关掉
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
      final wish = widget.wish;
      AppData.I.addTask(
        text,
        _day,
        wishId: wish?.id,
        color: wish?.color ?? _randomWishColor(),
        desc: desc,
      );
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

/// 修改心愿（标题 / 描述 / 颜色）—— 心愿详情页和人生清单编辑页共用。
/// 传了 [onDelete] 就在底部多一行「删除这个心愿」（弹层先关掉再回调）
Future<void> showEditWishSheet(BuildContext context, Wish w,
    {VoidCallback? onDelete}) {
  final title = TextEditingController(text: w.title);
  final desc = TextEditingController(text: w.desc ?? '');
  return showAppSheet(
    context,
    StatefulBuilder(
      builder: (context, setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              '修改心愿',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          TextField(
            controller: title,
            autofocus: true,
            decoration: fieldDeco('这辈子想做的一件事…'),
            style: const TextStyle(fontSize: 18),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: desc,
            decoration: fieldDeco('为什么想做这件事？（可选）'),
            style: const TextStyle(fontSize: 15),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 18),
          BigBtn(
            '保存',
            onTap: () {
              final t = title.text.trim();
              if (t.isEmpty) return;
              w.title = t;
              w.desc = desc.text.trim().isEmpty ? null : desc.text.trim();
              AppData.I.updateWish(w);
              Navigator.pop(context);
            },
          ),
          if (onDelete == null)
            const SizedBox(height: 6)
          else
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Text(
                    '删除这个心愿',
                    style: TextStyle(fontSize: 13.5, color: T.danger),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// 删除单个心愿的确认框；[after] 在真的删掉之后回调（比如把详情页 pop 掉）
void confirmDeleteWish(BuildContext context, Wish w, {VoidCallback? after}) {
  final related = AppData.I.tasksOfWish(w.id).length;
  showConfirmDialog(
    context,
    emoji: '🗑️',
    title: '删除这个心愿？',
    body: related == 0
        ? '「${w.title}」\n删除后无法恢复'
        : '「${w.title}」\n关联的 $related 个任务会变成杂事',
    onConfirm: () {
      AppData.I.deleteWish(w);
      snack(context, '已删除');
      after?.call();
    },
  );
}

/// 通用文本弹层 —— 加一条里程碑、改一条里程碑、记一笔笔记都用它
Future<void> showTextSheet(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  String okLabel = '保存',
  int maxLines = 1,
  required void Function(String text) onOk,
  VoidCallback? onDelete,
}) {
  final ctrl = TextEditingController(text: initial);
  return showAppSheet(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        TextField(
          controller: ctrl,
          autofocus: true,
          decoration: fieldDeco(hint),
          style: const TextStyle(fontSize: 17),
          maxLines: maxLines,
          minLines: 1,
          textInputAction:
              maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
          onSubmitted: maxLines == 1
              ? (v) {
                  if (v.trim().isEmpty) return;
                  Navigator.pop(context);
                  onOk(v.trim());
                }
              : null,
        ),
        const SizedBox(height: 16),
        BigBtn(
          okLabel,
          onTap: () {
            final t = ctrl.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(context);
            onOk(t);
          },
        ),
        if (onDelete == null)
          const SizedBox(height: 6)
        else
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                child: Text('删除',
                    style: TextStyle(fontSize: 13.5, color: T.danger)),
              ),
            ),
          ),
      ],
    ),
  );
}
