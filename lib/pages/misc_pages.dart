import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';

/// 年度回顾海报
class AnnualPage extends StatelessWidget {
  const AnnualPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppData.I;
    final year = DateTime.now().year;
    final doneThisYear =
        data.doneWishes.where((w) => w.doneAt!.year == year).toList();
    final heroesRow = (doneThisYear.isEmpty
            ? data.doneWishes.take(3)
            : doneThisYear.take(3))
        .map((w) => w.hero ?? AppData.heroes[0])
        .toList();
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
                      onTap: () => Navigator.pop(context)),
                  const Expanded(
                    child: Center(
                      child: Text('年度回顾',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
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
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$year',
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  color: T.accent,
                                  height: 1)),
                          const SizedBox(height: 10),
                          Text(
                              '你完成了${_cn(doneThisYear.length)}件\n很久以前想做的事',
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (final hero in heroesRow)
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(right: 5),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: hero,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _stat('为心愿推进', '${data.pushedDaysThisYear} 天'),
                          _stat('完成的任务', '${data.doneTaskCount} 个'),
                          _stat('清单还剩', '${data.activeWishes.length} 件'),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text('心愿 App · 年度报告',
                                style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFFC0C2CB))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              BigBtn('保存长图 · 分享',
                  onTap: () => snack(context, '已保存到相册（演示）')),
            ],
          ),
        ),
      ),
    );
  }

  String _cn(int n) {
    const names = ['零', '一', '两', '三', '四', '五', '六', '七', '八', '九'];
    return n < names.length ? ' ${names[n]} ' : ' $n ';
  }

  Widget _stat(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: T.field))),
      child: Row(
        children: [
          Text(k, style: const TextStyle(fontSize: 15, color: T.muted)),
          const Spacer(),
          Text(v,
              style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

/// 时光胶囊
class CapsulePage extends StatelessWidget {
  const CapsulePage({super.key});

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
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context)),
                  const Expanded(
                    child: Center(
                      child: Text('时光胶囊',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
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
                    _sealed(context, '给三十五岁的你', '封存中 · 距开启还有 1,247 天'),
                    const SizedBox(height: 11),
                    _sealed(context, '冰岛出发前打开',
                        '封存中 · 完成「去冰岛看极光」时开启'),
                    const SizedBox(height: 11),
                    Opacity(
                      opacity: .68,
                      child: SheetCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _lockIcon(open: true),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text('跑完全马那天的你',
                                          style:
                                              TextStyle(fontSize: 18)),
                                      SizedBox(height: 2),
                                      Text('已开启 · 2025.11.02',
                                          style: TextStyle(
                                              fontSize: 15.5,
                                              color: T.muted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text('「如果你真的跑完了，记得请自己吃顿好的。你值得。」',
                                style: TextStyle(
                                    fontSize: 15.5,
                                    height: 1.8,
                                    color: Color(0xFF5A5C66))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              BigBtn('写一封给未来的信',
                  bg: T.field,
                  fg: const Color(0xFF3A3A42),
                  onTap: () => snack(context, '写信（v1 暂无）')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sealed(BuildContext context, String title, String sub) {
    return SheetCard(
      child: Row(
        children: [
          _lockIcon(),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 2),
                Text(sub,
                    style:
                        const TextStyle(fontSize: 15.5, color: T.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockIcon({bool open = false}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: open ? T.field : T.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        open ? Icons.lock_open_rounded : Icons.lock_rounded,
        size: 18,
        color: open ? T.faint : T.accent,
      ),
    );
  }
}
