import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../data.dart';
import '../sheets.dart';
import '../theme.dart';
import '../ui.dart';
import 'login_page.dart';



/// 人生清单编辑 —— 新建 / 改标题描述颜色 / 左滑删除 / 多选批量删除
class WishEditPage extends StatefulWidget {
  const WishEditPage({super.key});
  @override
  State<WishEditPage> createState() => _WishEditPageState();
}

class _WishEditPageState extends State<WishEditPage> {
  bool _multi = false;
  final _sel = <String>{}; // 选中的心愿 id

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final active = AppData.I.activeWishes;
        final done = AppData.I.doneWishes;
        final all = [...active, ...done];
        // 别人删掉的心愿别留在选中集合里
        _sel.removeWhere((id) => !all.any((w) => w.id == id));
        return Scaffold(
          backgroundColor: T.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
              child: Column(
                children: [
                  _header(all),
                  const SizedBox(height: 12),
                  Expanded(
                    child: all.isEmpty
                        ? const Center(
                            child: Text(
                              '清单还是空的，写下第一件想做的事',
                              style: TextStyle(fontSize: 14.5, color: T.muted),
                            ),
                          )
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _hintBar(all),
                              for (final w in active) _card(w),
                              if (done.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _hint('已完成 ${done.length} 个'),
                                for (final w in done) _card(w),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 10),
                  if (_multi)
                    BigBtn(
                      _sel.isEmpty ? '删除选中的心愿' : '删除选中的 ${_sel.length} 个',
                      bg: _sel.isEmpty ? T.greyBar : T.danger,
                      fg: _sel.isEmpty ? T.faint : Colors.white,
                      onTap: _sel.isEmpty
                          ? null
                          : () => _confirmDeleteMany(
                              all.where((w) => _sel.contains(w.id)).toList(),
                            ),
                    )
                  else
                    BigBtn('新建心愿', onTap: _create),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- 顶栏 ----------
  Widget _header(List<Wish> all) {
    return Row(
      children: [
        PillBtn(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => _multi ? _exitMulti() : Navigator.pop(context),
        ),
        const Expanded(
          child: Center(
            child: Text(
              '人生清单编辑',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              _multi ? _exitMulti() : setState(() => _multi = all.isNotEmpty),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              _multi ? '取消' : '多选',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: T.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 列表顶部：普通态是操作提示，多选态是「已选 N 个 / 全选」
  Widget _hintBar(List<Wish> all) {
    if (!_multi) return _hint('左滑删除，轻点修改，右上角可多选');
    final allOn = _sel.length == all.length;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        children: [
          Text(
            '已选 ${_sel.length} 个',
            style: const TextStyle(fontSize: 13, color: T.muted),
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _sel.clear();
              if (!allOn) _sel.addAll(all.map((w) => w.id));
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                allOn ? '取消全选' : '全选',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: T.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 13, color: T.faint)),
  );

  // ---------- 心愿卡 ----------
  Widget _card(Wish w) {
    final on = _sel.contains(w.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(w.id),
        enabled: !_multi, // 多选时关掉左滑，避免和勾选打架
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: .22,
          children: [
            CustomSlidableAction(
              onPressed: (_) => confirmDeleteWish(context, w),
              backgroundColor: T.danger,
              padding: EdgeInsets.zero,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.delete_outline_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _multi ? _toggle(w) : _edit(w),
          onLongPress: _multi
              ? null
              : () => setState(() {
                  _multi = true;
                  _sel.add(w.id);
                }),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: T.shadowCard,
              border: on ? Border.all(color: T.accent, width: 1.5) : null,
            ),
            child: Row(
              children: [
                if (_multi) ...[_tick(on), const SizedBox(width: 12)],
                Container(
                  width: 5,
                  height: 24,
                  decoration: BoxDecoration(
                    color: w.done ? T.greyBar : w.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: w.done ? T.faint : T.ink,
                        ),
                      ),
                      if (w.desc != null && w.desc!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          w.desc!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: T.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!_multi)
                  const Icon(Icons.edit_rounded, size: 16, color: T.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 多选圆勾
  Widget _tick(bool on) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    width: 21,
    height: 21,
    decoration: BoxDecoration(
      color: on ? T.accent : Colors.transparent,
      shape: BoxShape.circle,
      border: on
          ? null
          : Border.all(color: const Color(0xFFCACCD6), width: 1.5),
    ),
    child: AnimatedScale(
      scale: on ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
    ),
  );

  void _toggle(Wish w) => setState(() {
    if (!_sel.remove(w.id)) _sel.add(w.id);
  });

  void _exitMulti() => setState(() {
    _multi = false;
    _sel.clear();
  });

  void _create() {
    if (!AppData.I.signedIn) {
      showBlurDialog(context, const LoginForm());
      return;
    }
    showNewWishSheet(context);
  }

  // ---------- 修改 / 删除（弹层和确认框在 sheets.dart，和心愿详情页共用）----------
  void _edit(Wish w) => showEditWishSheet(
    context,
    w,
    onDelete: () => confirmDeleteWish(context, w),
  );

  void _confirmDeleteMany(List<Wish> list) {
    if (list.isEmpty) return;
    final related = list
        .map((w) => AppData.I.tasksOfWish(w.id).length)
        .fold(0, (a, b) => a + b);
    _askDelete(
      title: '批量删除',
      body: related == 0
          ? '确定删除选中的 ${list.length} 个心愿吗？'
          : '确定删除选中的 ${list.length} 个心愿吗？关联的 $related 个任务会变成杂事。',
      onOk: () {
        AppData.I.deleteWishes(list);
        _exitMulti();
        snack(context, '已删除 ${list.length} 个');
      },
    );
  }

  void _askDelete({
    required String title,
    required String body,
    required VoidCallback onOk,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onOk();
            },
            style: TextButton.styleFrom(foregroundColor: T.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
