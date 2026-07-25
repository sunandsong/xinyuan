import 'package:flutter/material.dart';
import '../data.dart';
import '../pages/misc_pages.dart';
import '../pages/tree_page.dart';
import '../theme.dart';
import '../ui.dart';

class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final data = AppData.I;
        final done = data.doneWishes.length;
        final active = data.activeWishes.length;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(context, data, done, active),
            // 功能 + 账号（同一张卡）
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 16, 13, 0),
              child: SheetCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    _row(context, '荣誉陈列馆', '$done 枚勋章',
                        () => _push(context, const TreePage())),
                    _row(context, '${DateTime.now().year} 年度回顾', '',
                        () => _push(context, const AnnualPage())),
                    _row(context, '时光胶囊', '2 封',
                        () => _push(context, const CapsulePage())),
                    data.signedIn
                        ? _action(context, '退出登录', T.ink,
                            () => _confirmSignOut(context), last: true)
                        : _action(context, '登录 / 注册', T.accent,
                            () => _showLogin(context), last: true),
                  ],
                ),
              ),
            ),
            // 注销账号（一句灰字）
            if (data.signedIn)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 8),
                  child: GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: const Text('注销账号',
                        style: TextStyle(fontSize: 12.5, color: T.faint)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------- 顶部横幅 ----------
  Widget _header(BuildContext context, AppData data, int done, int active) {
    final top = MediaQuery.of(context).padding.top;
    final signed = data.signedIn;
    return Container(
      padding: EdgeInsets.fromLTRB(24, top + 26, 24, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C8DFF), Color(0xFF4772FA), Color(0xFF3A5CE0)],
          stops: [0, .55, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 大头像 + 光环（可编辑）
              GestureDetector(
                onTap: signed ? () => _editProfile(context) : null,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .35), width: 2),
                  ),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFFFFF), Color(0xFFE7ECFF)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: !signed
                        ? const Icon(Icons.person_rounded,
                            size: 38, color: Color(0xFFB9C3E8))
                        : (data.avatarEmoji != null
                            ? Text(data.avatarEmoji!,
                                style: const TextStyle(fontSize: 36))
                            : Text(_initial(data.nickname),
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: T.accent))),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: signed ? () => _editProfile(context) : null,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(signed ? data.nickname : '未登录',
                          style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                          signed
                              ? '记录了 ${data.totalDays} 天'
                              : '登录后云端同步你的心愿',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: .85))),
                    ],
                  ),
                ),
              ),
              if (!signed)
                GestureDetector(
                  onTap: () => _showLogin(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('登录',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: T.accent)),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _editProfile(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.edit_rounded,
                        size: 15, color: Colors.white.withValues(alpha: .55)),
                  ),
                ),
            ],
          ),
          if (signed) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                _stat('$done', '已完成'),
                _divider(),
                _stat('${data.streakDays}', '连续天数'),
                _divider(),
                _stat('$active', '进行中'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String v, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(v,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5, color: Colors.white.withValues(alpha: .8))),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 26,
        color: Colors.white.withValues(alpha: .2),
      );

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _row(BuildContext context, String title, String sub, VoidCallback onTap,
      {bool last = false}) {
    return TapRow(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: T.field))),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16.5))),
            if (sub.isNotEmpty)
              Text(sub, style: const TextStyle(fontSize: 15, color: T.faint)),
            const SizedBox(width: 3),
            const Icon(Icons.chevron_right, size: 17, color: T.faint),
          ],
        ),
      ),
    );
  }

  // 账号操作行（居中彩色文字）
  Widget _action(BuildContext context, String title, Color color,
      VoidCallback onTap,
      {bool last = false}) {
    return TapRow(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: T.field))),
        child: Row(
          children: [
            Text(title,
                style: TextStyle(fontSize: 16.5, color: color)),
          ],
        ),
      ),
    );
  }

  String _initial(String s) => s.isEmpty ? '心' : s.characters.first;

  // ---------- 编辑资料 ----------
  static const _avatarEmojis = [
    '🌟', '🌱', '🐱', '🌊', '🏔️', '🎈', '🍀', '🌸', '🐳', '🔥', '🌈', '🦊'
  ];

  void _editProfile(BuildContext context) {
    final data = AppData.I;
    final ctrl = TextEditingController(text: data.nickname);
    String? picked = data.avatarEmoji; // null = 文字（昵称首字）

    showAppSheet(
      context,
      StatefulBuilder(
        builder: (context, setSheet) {
          Widget option({String? emoji}) {
            final sel = picked == emoji;
            return GestureDetector(
              onTap: () => setSheet(() => picked = emoji),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFE7ECFF)],
                  ),
                  border: Border.all(
                      color: sel ? T.accent : const Color(0xFFE2E5F2),
                      width: sel ? 2.5 : 1),
                ),
                alignment: Alignment.center,
                child: emoji == null
                    ? Text(
                        _initial(ctrl.text.trim().isEmpty
                            ? data.nickname
                            : ctrl.text.trim()),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: T.accent))
                    : Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text('编辑资料',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
              ),
              TextField(
                controller: ctrl,
                autofocus: true,
                onChanged: (_) => setSheet(() {}),
                maxLength: 12,
                decoration: InputDecoration(
                  hintText: '昵称',
                  counterText: '',
                  filled: true,
                  fillColor: T.field,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide.none),
                ),
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 10),
                child: Text('选择头像',
                    style: TextStyle(fontSize: 14, color: T.muted)),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  option(), // 文字
                  for (final e in _avatarEmojis) option(emoji: e),
                ],
              ),
              const SizedBox(height: 18),
              BigBtn('保存', onTap: () {
                data.updateProfile(
                    nickname: ctrl.text.trim(),
                    avatarEmoji: picked,
                    clearEmoji: picked == null);
                Navigator.pop(context);
              }),
              const SizedBox(height: 6),
            ],
          );
        },
      ),
    );
  }

  // ---------- 登录 / 退出 / 注销 ----------
  void _showLogin(BuildContext context) {
    showAppSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('登录心愿',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
          const Text('登录后，心愿与勋章将云端同步',
              style: TextStyle(fontSize: 13.5, color: T.muted),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          BigBtn('微信一键登录',
              bg: const Color(0xFF3DBE6E), onTap: () {
            AppData.I.signIn();
            Navigator.pop(context);
            snack(context, '登录成功');
          }),
          const SizedBox(height: 10),
          BigBtn('手机号登录',
              bg: T.field, fg: T.ink, onTap: () {
            AppData.I.signIn();
            Navigator.pop(context);
            snack(context, '登录成功');
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定退出当前账号吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppData.I.signOut();
              snack(context, '已退出登录');
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text('注销后账号及数据将无法恢复，确定继续吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppData.I.signOut();
              snack(context, '账号已注销（演示）');
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE05A5A)),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
  }
}
