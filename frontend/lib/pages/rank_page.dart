import 'package:flutter/material.dart';
import '../analytics.dart';
import '../api/api.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';
import 'heat_detail_page.dart';
import 'user_detail_page.dart';

/// 六个榜单，分两类：前四个是「谁做得最多」（按用户排），后两个是「什么最热门」
/// （按心愿标题/景点名聚合，跟是谁完成的无关）。
/// 结构：(key, 类型 user|content, 标签, 图标, 排名依据说明, 数量单位)
/// user 榜服务端按用户资料上的计数排，计数跟着同步推送一起上传，看榜不额外产生写入；
/// content 榜服务端跨全部用户聚合心愿/打卡记录统计，同名算一起。
const _boards = [
  ('wish', 'user', '心愿', Icons.star_rounded, '谁点亮的心愿最多', '个心愿'),
  ('task', 'user', '任务', Icons.check_circle_rounded, '谁完成的任务最多', '个任务'),
  (
    'wishTitle',
    'content',
    '心愿热度',
    Icons.local_fire_department_rounded,
    '哪个心愿被完成得最多',
    '人完成',
  ),
  ('spot', 'content', '景点热度', Icons.location_on_rounded, '哪个景点被打卡得最多', '人打卡'),
  ('achv', 'user', '奖杯', Icons.emoji_events_rounded, '谁解锁的奖杯最多', '枚奖杯'),
  ('place', 'user', '足迹', Icons.public_rounded, '谁点亮的地图足迹最多', '处足迹'),
];

/// 名字保留原名不变：调用方还是 showRankSheet(context)，内部改成整页跳转
Future<void> showRankSheet(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const RankPage()),
);

/// 深色底子（跟荣誉殿堂/点亮世界一样的暗色调性），高亮色用 App 自己的
/// 蓝绿主题色而不是借来的金色——暗色氛围保留，主色跟全局对得上
class RankPage extends StatefulWidget {
  const RankPage({super.key});
  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage> {
  static const _bg1 = Color(0xFF17242A);
  static const _bg2 = Color(0xFF0C1416);
  static const _ink = Color(0xFFE8EEF8);
  static const _muted = Color(0xFF8FA8A8);
  static const _accentGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FC79A), Color(0xFF2E8F6B)],
  );
  // 头像兜底色：跟主题色板同色系但更饱和一点，压得住深色底
  static const _avatarPalette = [
    Color(0xFF5B8DEF),
    Color(0xFFE0A64B),
    Color(0xFFE0708A),
    Color(0xFF4FB88A),
    Color(0xFFA080E0),
  ];

  int _tab = 0;
  final _cache = <String, Map<String, dynamic>>{};
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Analytics.I.track('rank_view');
    if (AppData.I.signedIn) _load();
  }

  Future<void> _load() async {
    final board = _boards[_tab];
    final key = board.$1;
    if (_cache.containsKey(key)) return; // 切回已看过的榜不再请求
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (board.$2 == 'content') {
        _cache[key] = key == 'wishTitle'
            ? await RankApi.topWishes()
            : await RankApi.topSpots();
      } else {
        _cache[key] = await RankApi.top(key);
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '排行榜暂时打不开';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final signed = AppData.I.signedIn;
    return Scaffold(
      backgroundColor: _bg2,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bg1, _bg2],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            child: Container(
              height: 360,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: .9,
                  colors: [Color(0x293EA983), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(),
                if (!signed)
                  Expanded(child: _needLogin())
                else ...[
                  const SizedBox(height: 4),
                  _tabs(),
                  const SizedBox(height: 10),
                  Text(
                    _boards[_tab].$5,
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 6),
                  Expanded(child: _body()),
                  _myRow(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Row(
      children: [
        DarkPill(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Center(
            child: Text(
              '排 行 榜',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
                color: _ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: 38), // 跟返回按钮对称，标题保持居中
      ],
    ),
  );

  Widget _needLogin() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.leaderboard_rounded, size: 40, color: _muted),
        const SizedBox(height: 14),
        const Text(
          '登录后才能看排行榜，和大家比一比',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
        ),
      ],
    ),
  );

  /// 手机上 6 个 tab 塞不进一屏，横向滚动；平板放得下就整排居中，别靠左空一块
  Widget _tabs() {
    return SizedBox(
      height: 62,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
          for (var i = 0; i < _boards.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (i == _tab) return;
                setState(() => _tab = i);
                _load();
              },
              child: Container(
                width: 76,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: i == _tab ? _accentGrad : null,
                  color: i == _tab ? null : Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _boards[i].$4,
                      size: 18,
                      color: i == _tab ? Colors.white : _muted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _boards[i].$3,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: i == _tab
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: i == _tab ? Colors.white : _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _body() {
    final board = _boards[_tab];
    final isContent = board.$2 == 'content';
    final data = _cache[board.$1];
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      );
    }
    if (_loading && data == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: T.accent),
      );
    }
    final top = ((data?['top'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    if (top.isEmpty) {
      return Center(
        child: Text(
          isContent ? '还没有数据，快去攒点热度' : '还没有人上榜，你可以是第一个',
          style: const TextStyle(color: _muted, fontSize: 13.5),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        for (final u in top) isContent ? _contentRow(u, board) : _row(u),
      ],
    );
  }

  /// 名次是重点，做大做粗；完成数量只是佐证，做小做淡
  Widget _row(Map<String, dynamic> u) {
    final rank = u['rank'] as int? ?? 0;
    final isMe = u['isMe'] as bool? ?? false;
    final uid = u['uid'] as String?;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: uid == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserDetailPage(
                  uid: uid,
                  nickname: u['nickname'] as String?,
                  avatarUrl: u['avatarUrl'] as String?,
                ),
              ),
            ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isMe
              ? T.accent.withValues(alpha: .18)
              : Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(14),
          border: isMe
              ? Border.all(color: T.accent.withValues(alpha: .5))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(child: _avatar(u, 34)),
                if (u['gender'] != null)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: _genderBadge(u['gender'] as String),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${u['nickname']}${isMe ? '（我）' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                  color: _ink,
                ),
              ),
            ),
            Text(
              '${u['count']}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _muted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// content 榜的行：没有用户、没有头像，就是「排名 + 图标 + 标题 + 数量」
  Widget _contentRow(
    Map<String, dynamic> u,
    (String, String, String, IconData, String, String) board,
  ) {
    final rank = u['rank'] as int? ?? 0;
    final title = (u['title'] ?? u['place'] ?? '') as String;
    final count = u['count'] as int? ?? 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HeatDetailPage(
            kind: board.$1 == 'wishTitle' ? 'wish' : 'place',
            label: title,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.accent.withValues(alpha: .18),
                shape: BoxShape.circle,
              ),
              child: Icon(board.$4, size: 17, color: T.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
            Text(
              '$count${board.$6}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _muted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 有头像用头像，没有就拿昵称首字画一个纯色圆——总比灰扑扑的默认人形好认
  /// 小尺寸性别角标，贴在列表头像右下角；深色边框跟页面底色一致才衬得出来
  Widget _genderBadge(String gender) {
    final isMale = gender == '男';
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: isMale ? const Color(0xFF5B9BE0) : const Color(0xFFE87CA0),
        shape: BoxShape.circle,
        border: Border.all(color: _bg2, width: 1.3),
      ),
      child: Icon(
        isMale ? Icons.male_rounded : Icons.female_rounded,
        size: 8.5,
        color: Colors.white,
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> u, double size) {
    final url = u['avatarUrl'] as String?;
    final name = (u['nickname'] as String?) ?? '';
    final color = _avatarPalette[name.hashCode.abs() % _avatarPalette.length];
    final fallback = Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1) : '?',
        style: TextStyle(
          fontSize: size * .42,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    // 直接当普通图片链接渲染，不走 WishPhoto 那套私有云存储换新鲜链接的
    // 流程——排行榜头像允许是任意公开图床地址
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (_, child, p) => p == null ? child : fallback,
    );
  }

  /// 底部固定一条「我的名次」，没上榜也看得到自己的数字
  /// content 榜没有「我的名次」这个概念（不是按人排的），不显示这条
  Widget _myRow() {
    final board = _boards[_tab];
    if (board.$2 == 'content') return const SizedBox.shrink();
    final data = _cache[board.$1];
    if (data == null) return const SizedBox.shrink();
    final me = (data['me'] as Map?) ?? const {};
    final rank = me['rank'] as int?;
    final count = me['count'] as int? ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: _accentGrad,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Text(
              '我的名次',
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              rank == null ? '还没上榜，加把劲' : '第 $rank 名 · $count${board.$6}',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
