import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import '../data.dart';
import '../pages/login_page.dart';
import '../pages/world_page.dart';
import '../pages/misc_pages.dart';
import '../pages/tree_page.dart';
import '../pages/wish_edit_page.dart';
import '../photos.dart';
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    _row(
                      context,
                      '人生清单编辑',
                      '$active 个在清单里',
                      () => _push(context, const WishEditPage()),
                    ),
                    _row(
                      context,
                      '荣誉陈列馆',
                      '$done 枚勋章',
                      () => _push(context, const TreePage()),
                    ),
                    _row(
                      context,
                      '点亮世界',
                      '${litPlaceCount()} 处',
                      () => _push(context, const WorldPage()),
                    ),
                    _row(
                      context,
                      '时光胶囊',
                      '${data.letters.length} 封',
                      () => _push(context, const CapsulePage()),
                    ),
                    data.signedIn
                        ? _action(
                            context,
                            '退出登录',
                            T.ink,
                            () => _confirmSignOut(context),
                            last: true,
                          )
                        : _action(
                            context,
                            '登录 / 注册',
                            T.accent,
                            () => _showLogin(context),
                            last: true,
                          ),
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
                    child: const Text(
                      '注销账号',
                      style: TextStyle(fontSize: 12.5, color: T.faint),
                    ),
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
          colors: [Color(0xFF4B84DB), Color(0xFF4FA394), Color(0xFF5EB87C)],
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
                      color: Colors.white.withValues(alpha: .35),
                      width: 2,
                    ),
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
                    child: signed && data.avatarUrl != null
                        ? ClipOval(
                            child: WishPhoto(
                              data.avatarUrl!,
                              width: 72,
                              height: 72,
                              fallback: const Icon(
                                Icons.person_rounded,
                                size: 38,
                                color: Color(0xFFB9C3E8),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            size: 38,
                            color: Color(0xFFB9C3E8),
                          ),
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
                      Text(
                        signed ? data.nickname : '未登录',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (signed) ...[
                        const SizedBox(height: 4),
                        Text(
                          '记录了 ${data.totalDays} 天',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: .85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!signed)
                GestureDetector(
                  onTap: () => _showLogin(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '登录',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: T.accent,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _editProfile(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: Colors.white.withValues(alpha: .55),
                    ),
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
          Text(
            v,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: .8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 26,
    color: Colors.white.withValues(alpha: .2),
  );

  /// 「我的」页四个入口的唯一出口：未登录一律先弹登录。
  /// 这一页没被 PreviewShield 罩（不然点不到登录按钮），所以拦在这儿。
  void _push(BuildContext context, Widget page) {
    if (!AppData.I.signedIn) return _showLogin(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _row(
    BuildContext context,
    String title,
    String sub,
    VoidCallback onTap, {
    bool last = false,
  }) {
    return TapRow(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: T.field)),
              ),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16.5)),
            ),
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
  Widget _action(
    BuildContext context,
    String title,
    Color color,
    VoidCallback onTap, {
    bool last = false,
  }) {
    return TapRow(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: T.field)),
              ),
        child: Row(
          children: [
            Text(title, style: TextStyle(fontSize: 16.5, color: color)),
          ],
        ),
      ),
    );
  }

  /// 底部弹出的滚轮式年月日选择（系统 Cupertino 转轮，不用引三方）
  static Future<DateTime?> _pickBirthday(
    BuildContext context,
    DateTime initial,
  ) {
    var picked = initial;
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text('取消',
                          style: TextStyle(color: T.muted, fontSize: 15)),
                    ),
                    const Expanded(
                      child: Text('选择生日',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetCtx, picked),
                      child: const Text('确定',
                          style: TextStyle(
                              color: T.accent,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: DateTime(1920),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 按生日算周岁（弹层里选完还没保存时就要显示，所以不用 AppData.age）
  static int _ageOf(DateTime b) {
    final now = DateTime.now();
    var a = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) a--;
    return a < 0 ? 0 : a;
  }

  // ---------- 编辑资料 ----------
  void _editProfile(BuildContext context) {
    final data = AppData.I;
    final ctrl = TextEditingController(text: data.nickname);
    String? gender = data.gender;
    DateTime? birthday = data.birthday;

    showAppSheet(
      context,
      StatefulBuilder(
        builder: (context, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  '编辑资料',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              // 头像：点它选图上传，传完立即生效；没有头像时显示默认人形
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final url = await pickAndUploadAvatar(context);
                    if (url != null) setSheet(() {});
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFFFFF), Color(0xFFE7ECFF)],
                          ),
                          border: Border.all(color: const Color(0xFFE2E5F2)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: data.avatarUrl != null
                            ? WishPhoto(
                                data.avatarUrl!,
                                width: 76,
                                height: 76,
                                fallback: const Icon(Icons.person_rounded,
                                    size: 40, color: Color(0xFFB9C3E8)),
                              )
                            : const Icon(Icons.person_rounded,
                                size: 40, color: Color(0xFFB9C3E8)),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: T.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.photo_camera,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                maxLength: 12,
                decoration: InputDecoration(
                  hintText: '昵称',
                  counterText: '',
                  filled: true,
                  fillColor: T.field,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 12),
              // 性别 + 年龄：都是选填，性别再点一下可取消
              Row(
                children: [
                  for (final g in ['男', '女']) ...[
                    GestureDetector(
                      onTap: () =>
                          setSheet(() => gender = gender == g ? null : g),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: gender == g
                              ? T.accent.withValues(alpha: .14)
                              : T.field,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: gender == g ? T.accent : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          g,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: gender == g
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: gender == g ? T.accent : T.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // 生日：选了自动算年龄显示出来
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await _pickBirthday(
                          context,
                          birthday ?? DateTime(2000, 1, 1),
                        );
                        if (picked != null) {
                          setSheet(() => birthday = dOnly(picked));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: T.field,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          birthday == null
                              ? '生日'
                              : '${ymdDots(birthday!)} · ${_ageOf(birthday!)}岁',
                          style: TextStyle(
                            fontSize: 15,
                            color: birthday == null ? T.muted : T.ink,
                            fontWeight: birthday == null
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              BigBtn(
                '保存',
                onTap: () {
                  data.updateProfile(
                    nickname: ctrl.text.trim(),
                    gender: gender,
                    birthday: birthday,
                  );
                  Navigator.pop(context);
                  snack(context, '资料已保存 ✅');
                },
              ),
              const SizedBox(height: 6),
            ],
          );
        },
      ),
    );
  }

  // ---------- 登录 / 退出 / 注销 ----------
  void _showLogin(BuildContext context) {
    showBlurDialog(context, const LoginForm());
  }

  void _confirmSignOut(BuildContext context) {
    showConfirmDialog(
      context,
      emoji: '👋',
      title: '退出登录？',
      body: '云端数据都还在，重新登录就回来了',
      confirmText: '退出',
      onConfirm: () {
        AppData.I.logout();
        snack(context, '已退出登录');
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showConfirmDialog(
      context,
      emoji: '⚠️',
      title: '注销账号？',
      body: '账号和全部数据将无法恢复\n这一步没有后悔药',
      confirmText: '确认注销',
      onConfirm: () async {
        await AppData.I.deleteAccountRemote();
        if (!context.mounted) return;
        snack(context, '账号已注销，请重新登录');
        _showLogin(context); // 老账号已作废，直接把登录/注册摆到面前
      },
    );
  }
}
