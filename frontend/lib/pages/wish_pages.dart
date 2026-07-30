import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../api/api.dart';
import '../data.dart';
import '../notify.dart';
import '../photos.dart';
import '../presets.dart';
import '../sheets.dart';
import '../theme.dart';
import '../ui.dart';
import 'login_page.dart';
import 'share_page.dart';

/// 心愿详情（进行中）
class WishDetailPage extends StatelessWidget {
  const WishDetailPage({super.key, required this.wish});
  final Wish wish;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
          child: ListenableBuilder(
            listenable: AppData.I,
            builder: (context, _) {
              final tasks = AppData.I.tasksOfWish(wish.id);
              return Column(
                children: [
                  Row(
                    children: [
                      PillBtn(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      PillBtn(
                        icon: Icons.more_horiz_rounded,
                        onTap: () => _showMore(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _cover(context, tasks),
                        const SizedBox(height: 11),
                        _steps(context),
                        const SizedBox(height: 11),
                        _tasksCard(context, tasks),
                        const SizedBox(height: 11),
                        _notes(context),
                        const SizedBox(height: 11),
                        _photos(context),
                        const SizedBox(height: 11),
                        _related(context),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  BigBtn(
                    '完成这个心愿',
                    onTap: () {
                      if (!AppData.I.signedIn) {
                        showBlurDialog(context, const LoginForm());
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompleteWishPage(wish: wish),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------- 头卡：色点 + 标题 + 标签 + 统计条 ----------
  Widget _cover(BuildContext context, List<Task> tasks) {
    final c = wish.color;
    final wantDays = dOnly(
      DateTime.now(),
    ).difference(dOnly(wish.createdAt)).inDays;
    final doneTasks = tasks.where((t) => t.done).toList();
    final pushedDays = doneTasks.map((t) => dOnly(t.day)).toSet().length;
    final no = AppData.I.wishes.indexWhere((x) => x.id == wish.id) + 1;
    final hasDesc = wish.desc != null && wish.desc!.isNotEmpty;
    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WDot(c),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  wish.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: T.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showEditWishSheet(context, wish),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    hasDesc ? wish.desc! : '为什么想做这件事？写一句给以后的自己',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: hasDesc ? T.muted : T.faint,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    hasDesc ? Icons.edit_rounded : Icons.add_rounded,
                    size: 13,
                    color: T.faint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _tag('进行中', bg: c.withValues(alpha: .14), fg: c),
              if (no > 0) _tag('清单第 $no 项', bg: T.field, fg: T.muted),
              _targetTag(context),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: T.line),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('$wantDays', '天前写下'),
              _statDivider(),
              _stat('$pushedDays', '天在推进'),
              _statDivider(),
              _stat('${doneTasks.length}/${tasks.length}', '任务完成'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, {required Color bg, required Color fg}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
    ),
  );

  /// 目标日期做成标签胶囊，混在"进行中"那排标签里，不再单占一张卡
  Widget _targetTag(BuildContext context) {
    final left = wish.daysToTarget;
    final has = wish.targetAt != null;
    if (!has) {
      return GestureDetector(
        onTap: () => _pickTarget(context),
        child: _tag('+ 设个期限', bg: T.field, fg: T.muted),
      );
    }
    // 文案克制：超期不用红色警示，这份清单不是 deadline
    final label = left! > 0
        ? '还有 $left 天'
        : left == 0
        ? '就是今天'
        : '慢一点也没关系';
    return GestureDetector(
      onTap: () => _pickTarget(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 4, 6, 4),
        decoration: BoxDecoration(
          color: wish.color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_rounded, size: 12, color: wish.color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: wish.color,
              ),
            ),
            const SizedBox(width: 3),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                AppData.I.setWishTarget(wish, null);
                cancelWishReminder(wish);
              },
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: wish.color.withValues(alpha: .7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String v, String label) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: T.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 12, color: T.muted)),
      ],
    ),
  );

  Widget _statDivider() => Container(width: 1, height: 24, color: T.line);

  Future<void> _pickTarget(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: wish.targetAt ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 30),
    );
    if (picked == null) return;
    AppData.I.setWishTarget(wish, picked);
    // 到期当天早上九点提醒一次（没授权/不支持就静默跳过）
    await scheduleWishReminder(wish);
  }

  // ---------- 里程碑 ----------
  Widget _steps(BuildContext context) {
    final steps = wish.steps;
    final template = steps.isEmpty
        ? stepTemplateFor(wish.title)
        : const <String>[];
    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '里程碑',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (steps.isNotEmpty)
                Text(
                  '${wish.doneStepCount} / ${steps.length}',
                  style: const TextStyle(fontSize: 14, color: T.muted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (steps.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '拆成几步，就不再是一件遥远的事',
                style: TextStyle(fontSize: 15, color: T.faint),
              ),
            ),
            if (template.isNotEmpty)
              TapRow(
                onTap: () {
                  AppData.I.addSteps(wish, template);
                  snack(context, '已拆成 ${template.length} 步，可以随便改');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 17,
                        color: wish.color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '一键拆成 ${template.length} 步',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: T.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          // 时间线：完成的节点之间用实色连线，形成一段一段点亮的效果
          for (final s in steps) _stepRow(context, s),
          _addStepNode(context, empty: steps.isEmpty),
        ],
      ),
    );
  }

  Widget _stepRow(BuildContext context, WishStep s) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Cb(
                done: s.done,
                burstColor: wish.color,
                onTap: () => AppData.I.toggleStep(wish, s),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: s.done ? wish.color.withValues(alpha: .45) : T.field,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showTextSheet(
                  context,
                  title: '改一步',
                  hint: '这一步是…',
                  initial: s.title,
                  onOk: (t) => AppData.I.renameStep(wish, s, t),
                  onDelete: () => AppData.I.deleteStep(wish, s),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.title,
                        style: TextStyle(
                          fontSize: 15.5,
                          color: s.done ? T.faint : T.ink,
                          decoration: s.done
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: T.faint,
                        ),
                      ),
                    ),
                    if (s.done && s.doneAt != null)
                      Text(
                        md(s.doneAt!),
                        style: const TextStyle(fontSize: 12, color: T.faint),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 时间线收尾的"加一步"节点，接着最后一个里程碑往下长
  Widget _addStepNode(BuildContext context, {required bool empty}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTextSheet(
        context,
        title: '加一步',
        hint: '下一步先做什么？',
        okLabel: '加进里程碑',
        onOk: (t) => AppData.I.addStep(wish, t),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: T.line, width: 1.5),
            ),
            child: const Icon(Icons.add_rounded, size: 12, color: T.faint),
          ),
          const SizedBox(width: 10),
          Text(
            empty ? '自己写一步' : '再加一步',
            style: const TextStyle(fontSize: 15, color: T.muted),
          ),
        ],
      ),
    );
  }

  // ---------- 过程笔记 ----------
  Widget _notes(BuildContext context) {
    final notes = wish.notes;
    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '这一路',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (notes.isNotEmpty)
                Text(
                  '${notes.length} 条',
                  style: const TextStyle(fontSize: 14, color: T.muted),
                ),
            ],
          ),
          if (notes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                '随手记一句，以后回头看就是这件事的来龙去脉',
                style: TextStyle(fontSize: 15, color: T.faint),
              ),
            )
          else
            const SizedBox(height: 6),
          // 时间线：小圆点顺着一条竖线往下，最后接一个"记一笔"的入口
          for (final n in notes) _noteRow(context, n),
          _addNoteNode(context),
        ],
      ),
    );
  }

  Widget _addNoteNode(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTextSheet(
        context,
        title: '记一笔',
        hint: '今天为它做了什么 / 想到了什么…',
        okLabel: '记下来',
        maxLines: 4,
        onOk: (t) => AppData.I.addNote(wish, t),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Icon(Icons.edit_note_rounded, size: 19, color: wish.color),
          ),
          const SizedBox(width: 10),
          const Text(
            '记一笔',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: T.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteRow(BuildContext context, WishNote n) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              SizedBox(
                width: 28,
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: wish.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: wish.color.withValues(alpha: .35),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: T.field,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 16),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showTextSheet(
                  context,
                  title: '改一笔',
                  hint: '…',
                  initial: n.text,
                  maxLines: 4,
                  onOk: (t) {
                    n.text = t;
                    AppData.I.updateWish(wish);
                  },
                  onDelete: () => AppData.I.deleteNote(wish, n),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.text,
                      style: const TextStyle(fontSize: 15.5, height: 1.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ymdDots(n.at),
                      style: const TextStyle(fontSize: 12, color: T.faint),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 关联任务 ----------
  Widget _tasksCard(BuildContext context, List<Task> tasks) {
    final active = tasks.where((t) => !t.done).toList();
    final done = tasks.where((t) => t.done).toList();
    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '为它做点什么',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (tasks.isNotEmpty)
                Text(
                  '${done.length} / ${tasks.length}',
                  style: const TextStyle(fontSize: 14, color: T.muted),
                ),
            ],
          ),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '把它拆成一件件小事，日历里就会出现它的颜色',
                style: TextStyle(fontSize: 15, color: T.faint),
              ),
            )
          else ...[
            const SizedBox(height: 4),
            for (final t in active) _taskRow(context, t),
            for (final t in done) _taskRow(context, t),
          ],
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showNewTaskSheet(context, DateTime.now(), wish: wish),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 18, color: wish.color),
                  const SizedBox(width: 7),
                  const Text(
                    '加一个任务',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: T.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskRow(BuildContext context, Task t) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showEditTaskPage(context, t),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Cb(
              done: t.done,
              burstColor: wish.color,
              onTap: () => AppData.I.toggleTask(t),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: t.done ? T.faint : T.ink,
                  decoration: t.done ? TextDecoration.lineThrough : null,
                  decorationColor: T.faint,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              md(t.day),
              style: const TextStyle(fontSize: 13, color: T.faint),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 照片（真实图片，存云存储）----------
  Widget _photos(BuildContext context) {
    final photos = wish.photos;
    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '照片',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _addPhoto(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '加照片',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: T.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (photos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '路上的照片可以先存这儿，完成时再挑一张当凭证',
                style: TextStyle(fontSize: 15, color: T.faint),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (context, i) => _photoTile(context, photos[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _photoTile(BuildContext context, String url) {
    return GestureDetector(
      onLongPress: () => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除照片'),
          content: const Text('把这张照片从心愿里移除？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                AppData.I.removeWishPhoto(wish, url);
              },
              style: TextButton.styleFrom(foregroundColor: T.danger),
              child: const Text('删除'),
            ),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          // 链接过期或断网时不要炸成红屏，给一块灰底
          errorBuilder: (_, __, ___) => Container(
            width: 96,
            height: 96,
            color: T.field,
            child: const Icon(
              Icons.image_not_supported_outlined,
              size: 20,
              color: T.faint,
            ),
          ),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(width: 96, height: 96, color: T.field),
        ),
      ),
    );
  }

  Future<void> _addPhoto(BuildContext context) async {
    showAppSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _moreRow(Icons.photo_library_outlined, '从相册选', () {
            Navigator.pop(context);
            pickAndUploadWishPhoto(context, wish);
          }),
          _moreRow(Icons.photo_camera_outlined, '拍一张', () {
            Navigator.pop(context);
            pickAndUploadWishPhoto(context, wish, fromCamera: true);
          }),
        ],
      ),
    );
  }

  // ---------- 相关心愿 ----------
  Widget _related(BuildContext context) {
    final have = AppData.I.wishes.map((w) => w.title).toSet();
    final picks = relatedGoals(wish.title, exclude: have);
    if (picks.isEmpty) return const SizedBox.shrink();
    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '顺手也想做的',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final g in picks) _relatedChip(context, g)],
          ),
        ],
      ),
    );
  }

  Widget _relatedChip(BuildContext context, String g) {
    return GestureDetector(
      onTap: () {
        AppData.I.addWish(
          g,
          T.wishPalette[g.hashCode.abs() % T.wishPalette.length],
        );
        snack(context, '「$g」已写进清单');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: T.field,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(g, style: const TextStyle(fontSize: 14.5, color: T.ink)),
            const SizedBox(width: 5),
            const Icon(Icons.add_rounded, size: 16, color: T.accent),
          ],
        ),
      ),
    );
  }

  // ---------- 更多：编辑 / 分享 / 删除 ----------
  void _showMore(BuildContext context) {
    showAppSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _moreRow(Icons.edit_rounded, '修改心愿', () {
            Navigator.pop(context);
            showEditWishSheet(context, wish);
          }),
          _moreRow(Icons.auto_awesome_rounded, '做成宣告卡', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SharePage(wish: wish)),
            );
          }),
          _moreRow(Icons.ios_share_rounded, '生成分享码', () {
            Navigator.pop(context);
            _shareCode(context);
          }),
          _moreRow(Icons.delete_outline_rounded, '删除心愿', () {
            Navigator.pop(context);
            // 删完这条心愿就不存在了，详情页一起退掉
            confirmDeleteWish(
              context,
              wish,
              after: () => Navigator.pop(context),
            );
          }, danger: true),
        ],
      ),
    );
  }

  Widget _moreRow(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? T.danger : T.ink;
    return TapRow(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 16.5, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _shareCode(BuildContext context) async {
    if (!AppData.I.signedIn) {
      snack(context, '请先登录后再分享');
      return;
    }
    try {
      final path = await AppData.I.shareWish(wish);
      await Clipboard.setData(ClipboardData(text: path));
      if (!context.mounted) return;
      snack(context, '分享码已复制：$path');
    } on ApiException catch (e) {
      if (!context.mounted) return;
      snack(context, e.message);
    } catch (_) {
      if (!context.mounted) return;
      snack(context, '生成分享码失败，请重试');
    }
  }
}

/// 完成打卡：照片 + 一句话
class CompleteWishPage extends StatefulWidget {
  const CompleteWishPage({super.key, required this.wish});
  final Wish wish;
  @override
  State<CompleteWishPage> createState() => _CompleteWishPageState();
}

class _CompleteWishPageState extends State<CompleteWishPage> {
  int _hero = 0;
  final _quote = TextEditingController();
  final _loc = TextEditingController();

  @override
  Widget build(BuildContext context) {
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
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '完成了？',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SheetCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            onTap: () => setState(
                              () => _hero = (_hero + 1) % AppData.heroes.length,
                            ),
                            child: Container(
                              height: 170,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: AppData.heroes[_hero],
                                ),
                              ),
                              alignment: Alignment.bottomRight,
                              padding: const EdgeInsets.all(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .35),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '点击换一张（演示）',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 11),
                          TextField(
                            controller: _quote,
                            decoration: fieldDeco('这一刻想说的话…'),
                            style: const TextStyle(fontSize: 16.5),
                            maxLines: 2,
                            minLines: 1,
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: _loc,
                            decoration: fieldDeco('在哪儿完成的（可选，会点亮地图）'),
                            style: const TextStyle(fontSize: 16.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              BigBtn('完成这个心愿', onTap: _submit),
              const SizedBox(height: 8),
              const Text(
                '照片和这句话会永远留在清单里',
                style: TextStyle(fontSize: 15.5, color: T.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    AppData.I.completeWish(
      widget.wish,
      quote: _quote.text.trim(),
      location: _loc.text.trim(),
      heroIndex: _hero,
    );
    // 已经完成了就别再到期提醒
    cancelWishReminder(widget.wish);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SharePage(wish: widget.wish)),
    );
  }
}

/// 已完成详情（凭证）
class DoneWishPage extends StatelessWidget {
  const DoneWishPage({super.key, required this.wish});
  final Wish wish;

  @override
  Widget build(BuildContext context) {
    final tasks = AppData.I.tasksOfWish(wish.id);
    final firstTask = tasks.isEmpty ? null : tasks.last.day;
    final days = wish.doneAt!.difference(wish.createdAt).inDays;
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
                  const Spacer(),
                  PillBtn(
                    icon: Icons.ios_share_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SharePage(wish: wish)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SheetCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 170,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: wish.hero ?? AppData.heroes[0],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  wish.title,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: T.accentSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '已完成',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: T.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '「${wish.quote}」',
                            style: const TextStyle(fontSize: 16.5, height: 1.8),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (wish.location != null) wish.location!,
                              ymdDots(wish.doneAt!),
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 15.5,
                              color: T.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 11),
                    SheetCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '这条心愿的一生',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _step(ymDots(wish.createdAt), '写下心愿'),
                          if (firstTask != null)
                            _step(ymDots(firstTask), '第一个任务'),
                          _step(
                            ymDots(wish.doneAt!),
                            '完成 · 共 $days 天${tasks.isNotEmpty ? ' · ${tasks.length} 个任务' : ''}',
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(String date, String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 15.5,
                color: T.accent,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
