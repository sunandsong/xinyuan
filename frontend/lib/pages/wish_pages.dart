import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';
import 'login_page.dart';
import 'share_page.dart';

/// 心愿详情（进行中）
class WishDetailPage extends StatelessWidget {
  const WishDetailPage({super.key, required this.wish});
  final Wish wish;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
          child: ListenableBuilder(
            listenable: AppData.I,
            builder: (context, _) {
              return Column(
                children: [
                  Row(
                    children: [
                      PillBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.pop(context)),
                      const Spacer(),
                      PillBtn(
                          icon: Icons.more_horiz_rounded,
                          onTap: () => snack(context, '编辑 / 删除（v1 暂无）')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        SheetCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  WDot(wish.color),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Text(wish.title,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Padding(
                                padding: const EdgeInsets.only(left: 19),
                                child: Text(
                                    '写于 ${wish.createdAt.year} 年 ${wish.createdAt.month} 月',
                                    style: const TextStyle(
                                        fontSize: 15.5, color: T.muted)),
                              ),
                            ],
                          ),
                        ),
                        if (wish.desc != null &&
                            wish.desc!.isNotEmpty) ...[
                          const SizedBox(height: 11),
                          SheetCard(
                            child: Text(wish.desc!,
                                style: const TextStyle(
                                    fontSize: 16, height: 1.7)),
                          ),
                        ],
                        const SizedBox(height: 11),
                        SheetCard(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          child: Column(
                            children: const [
                              Icon(Icons.photo_camera_outlined,
                                  size: 24, color: T.grey),
                              SizedBox(height: 6),
                              Text('完成后在这里留一张照片和一句话',
                                  style: TextStyle(
                                      fontSize: 15, color: T.faint)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  BigBtn('完成这个心愿', onTap: () {
                    if (!AppData.I.signedIn) {
                      showBlurDialog(context, const LoginForm());
                      return;
                    }
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CompleteWishPage(wish: wish)));
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

}

/// 完成打卡：照片 + 一句话
class CompleteWishPage extends StatefulWidget {
  const CompleteWishPage({super.key, required this.wish});
  final Wish wish;
  @override
  State<CompleteWishPage> createState() => _CompleteWishPageState();
}

class _CompleteWishPageState extends State<CompleteWishPage> {
  int _hero = 0;
  final _quote = TextEditingController();
  final _loc = TextEditingController();

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
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context)),
                  const Expanded(
                    child: Center(
                      child: Text('完成了？',
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() =>
                                _hero = (_hero + 1) % AppData.heroes.length),
                            child: Container(
                              height: 170,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: AppData.heroes[_hero],
                                ),
                              ),
                              alignment: Alignment.bottomRight,
                              padding: const EdgeInsets.all(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black
                                      .withValues(alpha: .35),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('点击换一张（演示）',
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 11),
                          TextField(
                            controller: _quote,
                            decoration: fieldDeco('这一刻想说的话…'),
                            style: const TextStyle(fontSize: 16.5),
                            maxLines: 2,
                            minLines: 1,
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: _loc,
                            decoration: fieldDeco('在哪儿完成的（可选，会点亮地图）'),
                            style: const TextStyle(fontSize: 16.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              BigBtn('完成这个心愿', onTap: _submit),
              const SizedBox(height: 8),
              const Text('照片和这句话会永远留在清单里',
                  style: TextStyle(fontSize: 15.5, color: T.faint)),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    AppData.I.completeWish(widget.wish,
        quote: _quote.text.trim(),
        location: _loc.text.trim(),
        heroIndex: _hero);
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => SharePage(wish: widget.wish)));
  }
}

/// 已完成详情（凭证）
class DoneWishPage extends StatelessWidget {
  const DoneWishPage({super.key, required this.wish});
  final Wish wish;

  @override
  Widget build(BuildContext context) {
    final tasks = AppData.I.tasksOfWish(wish.id);
    final firstTask = tasks.isEmpty ? null : tasks.last.day;
    final days = wish.doneAt!.difference(wish.createdAt).inDays;
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
                  const Spacer(),
                  PillBtn(
                      icon: Icons.ios_share_rounded,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SharePage(wish: wish)))),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SheetCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 170,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: wish.hero ?? AppData.heroes[0],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(wish.title,
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: T.accentSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('已完成',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: T.accent)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('「${wish.quote}」',
                              style: const TextStyle(
                                  fontSize: 16.5, height: 1.8)),
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (wish.location != null) wish.location!,
                              ymdDots(wish.doneAt!),
                            ].join(' · '),
                            style: const TextStyle(
                                fontSize: 15.5, color: T.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 11),
                    SheetCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('这条心愿的一生',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          _step(ymDots(wish.createdAt), '写下心愿'),
                          if (firstTask != null)
                            _step(ymDots(firstTask), '第一个任务'),
                          _step(ymDots(wish.doneAt!),
                              '完成 · 共 $days 天${tasks.isNotEmpty ? ' · ${tasks.length} 个任务' : ''}',
                              bold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(String date, String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(date,
                style: const TextStyle(
                    fontSize: 15.5,
                    color: T.accent,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        bold ? FontWeight.w600 : FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}
