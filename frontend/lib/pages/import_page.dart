import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data.dart';
import '../presets.dart';
import '../theme.dart';
import '../ui.dart';

/// 从「人生必做清单」批量导入心愿
class ImportWishPage extends StatefulWidget {
  const ImportWishPage({super.key});
  @override
  State<ImportWishPage> createState() => _ImportWishPageState();
}

class _ImportWishPageState extends State<ImportWishPage> {
  static const _counts = [10, 30, 50, 100];
  static const _labels = ['入门', '经典', '精选', '必做'];
  final _rand = math.Random();

  int _count = 30;
  final Set<int> _sel = {};

  @override
  void initState() {
    super.initState();
    _resetSelection();
  }

  bool _exists(int i) =>
      AppData.I.wishes.any((w) => w.title == lifeGoals[i]);

  // 选中当前清单里所有「尚未在心愿中」的条目
  void _resetSelection() {
    _sel.clear();
    for (var i = 0; i < _count && i < lifeGoals.length; i++) {
      if (!_exists(i)) _sel.add(i);
    }
  }

  void _import() {
    if (_sel.isEmpty) return;
    var added = 0;
    for (final i in _sel) {
      if (_exists(i)) continue;
      AppData.I.addWish(
          lifeGoals[i], T.wishPalette[_rand.nextInt(T.wishPalette.length)]);
      added++;
    }
    Navigator.pop(context);
    snack(context, '已导入 $added 个心愿');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  PillBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context)),
                  const Expanded(
                    child: Center(
                      child: Text('人生必做清单',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: Text('挑一份清单，勾选后一键写进你的心愿',
                  style: TextStyle(fontSize: 13.5, color: T.muted)),
            ),
            // 份量切换
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (var k = 0; k < _counts.length; k++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _count = _counts[k];
                          _resetSelection();
                        }),
                        child: Container(
                          margin: EdgeInsets.only(
                              right: k == _counts.length - 1 ? 0 : 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _count == _counts[k] ? T.plusGrad : null,
                            color: _count == _counts[k] ? null : Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: T.shadowCard,
                          ),
                          child: Column(
                            children: [
                              Text(_labels[k],
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _count == _counts[k]
                                          ? Colors.white.withValues(alpha: .9)
                                          : T.muted)),
                              const SizedBox(height: 2),
                              Text('${_counts[k]} 件',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _count == _counts[k]
                                          ? Colors.white
                                          : T.ink)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 清单
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _count,
                itemBuilder: (context, i) {
                  final exists = _exists(i);
                  final on = _sel.contains(i);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: exists
                        ? null
                        : () => setState(() {
                              if (on) {
                                _sel.remove(i);
                              } else {
                                _sel.add(i);
                              }
                            }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                            color: on ? T.accent.withValues(alpha: .55) : T.line,
                            width: on ? 1.5 : 1),
                      ),
                      child: Row(
                        children: [
                          _check(on, exists),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(lifeGoals[i],
                                style: TextStyle(
                                    fontSize: 16,
                                    color: exists ? T.faint : T.ink)),
                          ),
                          if (exists)
                            const Text('已在清单',
                                style: TextStyle(fontSize: 12, color: T.faint)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // 底部导入按钮
            Container(
              color: T.bg,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: BigBtn(
                _sel.isEmpty ? '选几个想做的事' : '导入 ${_sel.length} 个心愿',
                onTap: _sel.isEmpty ? null : _import,
                bg: _sel.isEmpty ? T.grey : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _check(bool on, bool exists) {
    final fill = exists ? T.grey : (on ? T.accent : Colors.transparent);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(7),
        border: (on || exists)
            ? null
            : Border.all(color: const Color(0xFFCACCD6), width: 1.5),
      ),
      child: (on || exists)
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}
