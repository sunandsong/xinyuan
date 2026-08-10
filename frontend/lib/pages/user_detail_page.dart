import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme.dart';
import '../ui.dart';
import 'tree_page.dart' show achvMeta;

/// 排行榜点进的用户主页：只给公开信息（头像/昵称/性别 + 四项统计与名次 + 荣誉墙），
/// 不涉及对方心愿/任务/打卡的具体内容。深色调性跟排行榜、荣誉殿堂统一。
class UserDetailPage extends StatefulWidget {
  const UserDetailPage({
    super.key,
    required this.uid,
    this.nickname,
    this.avatarUrl,
  });
  final String uid;
  // 从排行榜列表带过来的，先垫一下，别一进页面就空白
  final String? nickname;
  final String? avatarUrl;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  static const _bg1 = Color(0xFF17242A);
  static const _bg2 = Color(0xFF0C1416);
  static const _ink = Color(0xFFE8EEF8);
  static const _muted = Color(0xFF8FA8A8);
  static const _avatarPalette = [
    Color(0xFF5B8DEF),
    Color(0xFFE0A64B),
    Color(0xFFE0708A),
    Color(0xFF4FB88A),
    Color(0xFFA080E0),
  ];
  static const _boards = [
    ('doneCount', '心愿', Icons.star_rounded, '个心愿'),
    ('taskCount', '任务', Icons.check_circle_rounded, '个任务'),
    ('achvCount', '奖杯', Icons.emoji_events_rounded, '枚奖杯'),
    ('placeCount', '足迹', Icons.public_rounded, '处足迹'),
  ];

  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await RankApi.userProfile(widget.uid);
      if (mounted) setState(() => _data = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '打不开这个主页');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = (_data?['nickname'] as String?) ?? widget.nickname ?? '';
    final avatarUrl = (_data?['avatarUrl'] as String?) ?? widget.avatarUrl;
    final gender = _data?['gender'] as String?;
    final age = _data?['age'] as int?;
    final createdAt = _data?['createdAt'] as num?;
    final days = createdAt == null
        ? null
        : DateTime.now()
                  .difference(
                    DateTime.fromMillisecondsSinceEpoch(createdAt.toInt()),
                  )
                  .inDays +
              1;
    final counts = (_data?['counts'] as Map?) ?? const {};
    final ranks = (_data?['ranks'] as Map?) ?? const {};
    final achvSlugs = ((_data?['achievements'] as List?) ?? const [])
        .cast<String>();

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
                Padding(
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
                            '主 页',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 4,
                              color: _ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 38),
                    ],
                  ),
                ),
                if (_error != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: _muted, fontSize: 13),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipOval(child: _avatar(nickname, avatarUrl, 84)),
                              if (gender != null)
                                Positioned(
                                  right: -1,
                                  bottom: -1,
                                  child: _genderBadge(gender),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            nickname,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                        if (days != null || age != null) ...[
                          const SizedBox(height: 4),
                          Center(
                            child: Text(
                              [
                                if (age != null) '$age 岁',
                                if (days != null) '记录了 $days 天',
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 13,
                                color: _muted,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_data == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: T.accent,
                              ),
                            ),
                          )
                        else ...[
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.7,
                            children: [
                              for (final b in _boards)
                                _statCard(
                                  b.$3,
                                  b.$2,
                                  (counts[b.$1] as num?)?.toInt() ?? 0,
                                  ranks[b.$1] as num?,
                                ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          const Text(
                            '荣誉墙',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (achvSlugs.isEmpty)
                            const Text(
                              '还没解锁勋章',
                              style: TextStyle(fontSize: 13, color: _muted),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final slug in achvSlugs)
                                  if (achvMeta[slug] != null)
                                    _achvChip(achvMeta[slug]!),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name, String? url, double size) {
    final color = _avatarPalette[name.hashCode.abs() % _avatarPalette.length];
    final fallback = Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1) : '?',
        style: TextStyle(
          fontSize: size * .38,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (_, child, p) => p == null ? child : fallback,
    );
  }

  Widget _genderBadge(String gender) {
    final isMale = gender == '男';
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isMale ? const Color(0xFF5B9BE0) : const Color(0xFFE87CA0),
        shape: BoxShape.circle,
        border: Border.all(color: _bg2, width: 2),
      ),
      child: Icon(
        isMale ? Icons.male_rounded : Icons.female_rounded,
        size: 15,
        color: Colors.white,
      ),
    );
  }

  Widget _statCard(IconData icon, String label, int count, num? rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: T.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  rank == null ? label : '$label · 第$rank名',
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _achvChip((String, String, Color) meta) {
    final (emoji, name, color) = meta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(name, style: TextStyle(fontSize: 12.5, color: color)),
        ],
      ),
    );
  }
}
