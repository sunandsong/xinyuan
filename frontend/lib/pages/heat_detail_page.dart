import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme.dart';
import '../ui.dart';
import 'user_detail_page.dart';

/// 心愿热度/景点热度榜点进来的穿透页：谁完成过这个心愿 / 谁打卡过这个景点。
/// 深色调性跟排行榜、用户主页统一，点某一行接着进那个人的主页。
class HeatDetailPage extends StatefulWidget {
  const HeatDetailPage({super.key, required this.kind, required this.label});

  /// 'wish' | 'place'
  final String kind;

  /// 心愿标题 / 景点名
  final String label;

  @override
  State<HeatDetailPage> createState() => _HeatDetailPageState();
}

class _HeatDetailPageState extends State<HeatDetailPage> {
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

  List<Map<String, dynamic>>? _users;
  String? _error;

  bool get _isWish => widget.kind == 'wish';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = _isWish
          ? await RankApi.wishCompleters(widget.label)
          : await RankApi.placeVisitors(widget.label);
      final users = ((r['users'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      if (mounted) setState(() => _users = users);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '打不开这个列表');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            '谁 完 成 了',
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _isWish ? '「${widget.label}」' : '去过「${widget.label}」',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      );
    }
    if (_users == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: T.accent),
      );
    }
    if (_users!.isEmpty) {
      return const Center(
        child: Text('还没有人', style: TextStyle(color: _muted, fontSize: 13.5)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [for (final u in _users!) _row(u)],
    );
  }

  Widget _row(Map<String, dynamic> u) {
    final uid = u['uid'] as String?;
    final nickname = (u['nickname'] as String?) ?? '匿名';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: uid == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserDetailPage(
                  uid: uid,
                  nickname: nickname,
                  avatarUrl: u['avatarUrl'] as String?,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(child: _avatar(u, 36)),
                if (u['gender'] != null)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: _genderBadge(u['gender'] as String),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: _muted),
          ],
        ),
      ),
    );
  }

  /// 小尺寸性别角标，贴在列表头像右下角
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
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (_, child, p) => p == null ? child : fallback,
    );
  }
}
