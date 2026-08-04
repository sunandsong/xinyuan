import 'package:flutter/material.dart';
import '../api/api.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';

/// 四个榜单：心愿实现数 / 任务完成数 / 奖杯数 / 地图点亮数。
/// 服务端按用户资料上的计数排，计数跟着同步推送一起上传，看榜不额外产生写入。
const _boards = [
  ('wish', '心愿', Icons.star_rounded),
  ('task', '任务', Icons.check_circle_rounded),
  ('achv', '奖杯', Icons.emoji_events_rounded),
  ('place', '足迹', Icons.public_rounded),
];

Future<void> showRankSheet(BuildContext context) =>
    showAppSheet(context, const _RankSheet());

class _RankSheet extends StatefulWidget {
  const _RankSheet();
  @override
  State<_RankSheet> createState() => _RankSheetState();
}

class _RankSheetState extends State<_RankSheet> {
  int _tab = 0;
  final _cache = <String, Map<String, dynamic>>{};
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final by = _boards[_tab].$1;
    if (_cache.containsKey(by)) return; // 切回已看过的榜不再请求
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _cache[by] = await RankApi.top(by);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '排行榜暂时打不开';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!AppData.I.signedIn) return _needLogin();
    final data = _cache[_boards[_tab].$1];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('排 行 榜',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 3)),
        const SizedBox(height: 14),
        _tabs(),
        const SizedBox(height: 12),
        SizedBox(
          height: 340,
          child: _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: T.muted, fontSize: 13)))
              : (_loading && data == null)
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _list(data),
        ),
        if (data != null) _myRow(data),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _needLogin() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Text('登录后才能看排行榜',
            textAlign: TextAlign.center,
            style: TextStyle(color: T.muted, fontSize: 14)),
      );

  Widget _tabs() {
    return Row(
      children: [
        for (var i = 0; i < _boards.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (i == _tab) return;
                setState(() => _tab = i);
                _load();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: i == _tab ? T.accent.withValues(alpha: .12) : T.field,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(_boards[i].$3,
                        size: 17, color: i == _tab ? T.accent : T.muted),
                    const SizedBox(height: 3),
                    Text(_boards[i].$2,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                i == _tab ? FontWeight.w700 : FontWeight.w500,
                            color: i == _tab ? T.accent : T.muted)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _list(Map<String, dynamic>? data) {
    final top = (data?['top'] as List?) ?? const [];
    if (top.isEmpty) {
      return const Center(
        child: Text('还没有人上榜，你可以是第一个',
            style: TextStyle(color: T.muted, fontSize: 13.5)),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: top.length,
      itemBuilder: (_, i) => _row(top[i] as Map<String, dynamic>),
    );
  }

  Widget _row(Map<String, dynamic> u) {
    final rank = u['rank'] as int? ?? 0;
    final isMe = u['isMe'] as bool? ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? T.accent.withValues(alpha: .10) : T.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(width: 30, child: _medal(rank)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${u['nickname']}${isMe ? '（我）' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                  color: T.ink),
            ),
          ),
          Text('${u['count']}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: T.accent,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  /// 前三名给奖牌色，其余显示数字
  Widget _medal(int rank) {
    const colors = {1: Color(0xFFE8B44C), 2: Color(0xFFB9C0CF), 3: Color(0xFFC98F5E)};
    final c = colors[rank];
    if (c == null) {
      return Text('$rank',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, color: T.muted, fontWeight: FontWeight.w600));
    }
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      child: Text('$rank',
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  /// 底部固定一条「我的名次」，没上榜也看得到自己的数字
  Widget _myRow(Map<String, dynamic> data) {
    final me = (data['me'] as Map?) ?? const {};
    final rank = me['rank'] as int?;
    final count = me['count'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: T.accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('我的名次',
              style: TextStyle(fontSize: 13.5, color: T.muted)),
          const Spacer(),
          Text(
            rank == null ? '还没上榜' : '第 $rank 名 · $count',
            style: const TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w700, color: T.accent),
          ),
        ],
      ),
    );
  }
}
