import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../data.dart';
import '../pages/login_page.dart';
import '../pages/notification_settings_page.dart';
import '../pages/world_page.dart';
import '../pages/misc_pages.dart';
import '../pages/tree_page.dart';
import '../pages/wish_edit_page.dart';
import '../photos.dart';
import '../theme.dart';
import '../ui.dart';
import '../version.dart';

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
                child: LayoutBuilder(
                  builder: (context, cons) {
                    // 卡片拉满两侧，平板上比手机宽——字号/图标跟着卡片实际
                    // 宽度按比例放大，不然内容照手机尺寸排，右侧箭头前面空一大截
                    final s = cardContentScale(context, cons.maxWidth);
                    return Column(
                      children: [
                        _row(
                          context,
                          '人生清单编辑',
                          '$active 个在清单里',
                          () => _push(context, const WishEditPage()),
                          scale: s,
                        ),
                        _row(
                          context,
                          '荣誉陈列馆',
                          '$done 枚勋章',
                          () => _push(context, const TreePage()),
                          scale: s,
                        ),
                        _row(
                          context,
                          '点亮世界',
                          '${litPlaceCount()} 处',
                          () => _push(context, const WorldPage()),
                          scale: s,
                        ),
                        _row(
                          context,
                          '时光胶囊',
                          '${data.letters.length} 封',
                          () => _push(context, const CapsulePage()),
                          scale: s,
                        ),
                        _row(
                          context,
                          '通知提醒',
                          '',
                          () =>
                              _push(context, const NotificationSettingsPage()),
                          scale: s,
                        ),
                        _row(
                          context,
                          '意见反馈',
                          '',
                          () => data.signedIn
                              ? _openFeedback(context)
                              : _showLogin(context),
                          scale: s,
                        ),
                        // 「不上榜」隐私开关：只对登录用户显示——未登录本来就不在榜上
                        if (data.signedIn) _rankSwitchRow(data, scale: s),
                        _row(
                          context,
                          '用户协议',
                          '',
                          () => openLegalPage('/terms'),
                          scale: s,
                        ),
                        _row(
                          context,
                          '隐私政策',
                          '',
                          () => openLegalPage('/privacy'),
                          scale: s,
                        ),
                        // 版本号：跟其它设置项同一张卡、同一种排版，不能点，所以没有 chevron。
                        // 手动跟 pubspec.yaml 的 version 保持一致就行，改动不频繁，
                        // 没必要为这一行字多引一个 package_info 插件
                        _infoRow('版本', kAppVersion, scale: s),
                        data.signedIn
                            ? _action(
                                context,
                                '退出登录',
                                T.ink,
                                () => _confirmSignOut(context),
                                last: true,
                                scale: s,
                              )
                            : _action(
                                context,
                                '登录 / 注册',
                                T.accent,
                                () => _showLogin(context),
                                last: true,
                                scale: s,
                              ),
                      ],
                    );
                  },
                ),
              ),
            ),
            // 注销账号（一句灰字）
            if (data.signedIn)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 20),
                  child: GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: const Text(
                      '注销账号',
                      style: TextStyle(fontSize: 12.5, color: T.faint),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 20),
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
              // 大头像 + 光环（可编辑）+ 右下角性别角标（没填就不显示）
              GestureDetector(
                onTap: signed ? () => _editProfile(context) : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
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
                    if (signed && data.gender != null)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: _genderBadge(data.gender!),
                      ),
                  ],
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

  /// 头像右下角的性别角标：男蓝女粉，白边圆底压住头部渐变，没设性别时调用方不显示。
  /// 试过不带圆圈直接放色块图标，跟渐变背景撞色看不清，还是圆底最清楚
  Widget _genderBadge(String gender) {
    final isMale = gender == '男';
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isMale ? const Color(0xFF5B9BE0) : const Color(0xFFE87CA0),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        isMale ? Icons.male_rounded : Icons.female_rounded,
        size: 14,
        color: Colors.white,
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
    double scale = 1,
  }) {
    return TapRow(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 13 * scale),
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: T.field)),
              ),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 16.5 * scale)),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: TextStyle(fontSize: 15 * scale, color: T.faint),
              ),
            SizedBox(width: 3 * scale),
            Icon(Icons.chevron_right, size: 17 * scale, color: T.faint),
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
    double scale = 1,
  }) {
    return TapRow(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 13 * scale),
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: T.field)),
              ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16.5 * scale, color: color),
            ),
          ],
        ),
      ),
    );
  }

  /// 跟 _row 同一种排版的静态信息行——不能点，所以没有 TapRow 和 chevron
  /// 「不上榜」隐私开关行：开了之后排行榜和热度穿透名单里都不出现自己
  Widget _rankSwitchRow(AppData data, {double scale = 1}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6 * scale),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: T.field)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('排行榜隐身', style: TextStyle(fontSize: 16.5 * scale)),
                SizedBox(height: 2 * scale),
                Text(
                  '开启后不出现在任何榜单里',
                  style: TextStyle(fontSize: 12 * scale, color: T.faint),
                ),
              ],
            ),
          ),
          Switch(
            value: data.hideFromRank,
            activeThumbColor: T.accent,
            onChanged: (v) => data.setHideFromRank(v),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String title,
    String value, {
    bool last = false,
    double scale = 1,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 13 * scale),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: T.field)),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 16.5 * scale)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 15 * scale, color: T.faint),
          ),
        ],
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
                      child: const Text(
                        '取消',
                        style: TextStyle(color: T.muted, fontSize: 15),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '选择生日',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetCtx, picked),
                      child: const Text(
                        '确定',
                        style: TextStyle(
                          color: T.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  /// 编辑资料弹层里「标签 + 右侧内容」的一行，性别、生日共用这套排版
  Widget _formRow({
    required String label,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: T.field,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                color: T.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            child,
          ],
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
                                fallback: const Icon(
                                  Icons.person_rounded,
                                  size: 40,
                                  color: Color(0xFFB9C3E8),
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 40,
                                color: Color(0xFFB9C3E8),
                              ),
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
                          child: const Icon(
                            Icons.photo_camera,
                            size: 12,
                            color: Colors.white,
                          ),
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
              const SizedBox(height: 10),
              // 性别：图标 + 文字卡片，选中的描边+浅底+主题色，未选灰字白底
              _formRow(
                label: '性别',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final g in ['男', '女'])
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setSheet(() => gender = gender == g ? null : g),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: gender == g
                                  ? T.accent.withValues(alpha: .12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: gender == g ? T.accent : T.line,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  g == '男'
                                      ? Icons.male_rounded
                                      : Icons.female_rounded,
                                  size: 15,
                                  color: gender == g ? T.accent : T.muted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  g,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: gender == g ? T.accent : T.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 生日：选了自动算年龄显示出来，整行都能点
              _formRow(
                label: '生日',
                onTap: () async {
                  final picked = await _pickBirthday(
                    context,
                    birthday ?? DateTime(2000, 1, 1),
                  );
                  if (picked != null) setSheet(() => birthday = dOnly(picked));
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      birthday == null
                          ? '未设置'
                          : '${ymdDots(birthday!)} · ${_ageOf(birthday!)}岁',
                      style: TextStyle(
                        fontSize: 15,
                        color: birthday == null ? T.muted : T.ink,
                        fontWeight: birthday == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: T.muted.withValues(alpha: .7),
                    ),
                  ],
                ),
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

  // ---------- 意见反馈 ----------
  void _openFeedback(BuildContext context) {
    final ctrl = TextEditingController();
    bool loading = false;

    showAppSheet(
      context,
      StatefulBuilder(
        builder: (context, setSheet) {
          Future<void> submit() async {
            final text = ctrl.text.trim();
            if (text.isEmpty) {
              snack(context, '写点内容再提交吧');
              return;
            }
            setSheet(() => loading = true);
            try {
              await FeedbackApi.submit(text);
              if (!context.mounted) return;
              Navigator.pop(context);
              snack(context, '收到啦，谢谢反馈 ✅');
            } on ApiException catch (e) {
              setSheet(() => loading = false);
              snack(context, e.message);
            } catch (_) {
              setSheet(() => loading = false);
              snack(context, '提交失败，请重试');
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  '意见反馈',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  '哪里不好用、想要什么功能，都可以说说',
                  style: TextStyle(fontSize: 13, color: T.muted),
                  textAlign: TextAlign.center,
                ),
              ),
              TextField(
                controller: ctrl,
                maxLines: 5,
                maxLength: 500,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '说说你的想法…',
                  filled: true,
                  fillColor: T.field,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 6),
              BigBtn(loading ? '提交中…' : '提交', onTap: loading ? () {} : submit),
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
