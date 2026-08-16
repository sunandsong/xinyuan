import 'dart:io' show Directory, File;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:share_plus/share_plus.dart';

import 'data.dart';
import 'photos.dart';
import 'theme.dart';
import 'ui.dart';

/// 海报样式：背景图 + 大标语（任务成绩单一组，心愿清单一组）
const _taskStyles = [
  (asset: 'assets/posters/bg1.jpg', slogan: '把想做的事\n一件件做完'),
  (asset: 'assets/posters/bg2.jpg', slogan: '心里有光\n脚下有路'),
  (asset: 'assets/posters/bg3.jpg', slogan: '日拱一卒\n功不唐捐'),
  (asset: 'assets/posters/bg4.jpg', slogan: '每一天\n都算数'),
  (asset: 'assets/posters/bg5.jpg', slogan: '说到\n就做到'),
];
const _wishStyles = [
  (asset: 'assets/posters/wish1.jpg', slogan: '心之所向\n素履以往'),
  (asset: 'assets/posters/wish2.jpg', slogan: '愿望说出来\n就亮了'),
  (asset: 'assets/posters/wish3.jpg', slogan: '翻过山\n就见到光'),
  (asset: 'assets/posters/wish4.jpg', slogan: '奔赴热爱\n不负此生'),
  (asset: 'assets/posters/wish5.jpg', slogan: '微光会聚成\n星海'),
];

/// 「心愿达成」弹窗的内置底图（登顶云海 / 抵达海边 / 晨光窗边 / 星空草地）。
/// 管理端 poster_done 表下发的图优先，这四张是拉不到时的兜底，
/// 顺序跟后端 seed-content.ts 的 DONE_SLOGANS 一致。
const donePosterAssets = [
  'assets/posters/done1.jpg',
  'assets/posters/done2.jpg',
  'assets/posters/done3.jpg',
  'assets/posters/done4.jpg',
];

/// 成绩单海报分享：底部弹层，左右滑选背景，一键分享成图片。
/// [subtitle] 头像旁小字（如「人生清单 · 2026.8成绩单」），
/// [summary] 底部一句话（如「8月我完成了 12 个任务」），
/// [stats] 数据栏 (标签, 数值)。
void showPosterShare(
  BuildContext context, {
  required String subtitle,
  required String summary,
  required List<(String, String)> stats,
  bool forWishes = false, // true 用心愿背景组
}) {
  final styles = forWishes ? _wishStyles : _taskStyles;
  // 弹层滑入的同时预热解码背景图，别等滑到那页才卡一下
  for (final st in styles) {
    precacheImage(AssetImage(st.asset), context);
  }
  var page = 0;
  final keys = List.generate(styles.length, (_) => GlobalKey());
  final controller = PageController(viewportFraction: .88);
  showModalBottomSheet(
    context: context,
    backgroundColor: T.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
          top: 16,
          bottom: MediaQuery.of(ctx).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: MediaQuery.of(ctx).size.height * .56,
              child: PageView.builder(
                controller: controller,
                itemCount: styles.length,
                onPageChanged: (i) => setSheet(() => page = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  // Center 给海报松约束，保住 3:4 比例和圆角；
                  // RepaintBoundary 必须贴着海报本体，截图才不带透明边
                  child: Center(
                    child: RepaintBoundary(
                      key: keys[i],
                      child: _poster(styles[i], subtitle, summary, stats),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < styles.length; i++)
                  Container(
                    width: page == i ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: page == i ? T.accent : T.greyBar,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BigBtn('分享图片', onTap: () => _shareImage(keys[page])),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _shareImage(GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('${Directory.systemTemp.path}/chengjidan.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
}

/// 海报本体：背景图 + 压暗渐变 + 头像昵称 + 大标语 + 数据栏
Widget _poster(
  ({String asset, String slogan}) s,
  String subtitle,
  String summary,
  List<(String, String)> stats,
) {
  return AspectRatio(
    aspectRatio: 3 / 4,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(s.asset, fit: BoxFit.cover),
          // 底部压暗，保证标语和数据在任何背景上都读得清
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .45, 1],
                colors: [
                  Color(0x33000000),
                  Color(0x00000000),
                  Color(0x8C000000),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .28),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .5),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AppData.I.avatarUrl != null
                          ? WishPhoto(
                              AppData.I.avatarUrl!,
                              width: 36,
                              height: 36,
                              fallback: const Icon(
                                Icons.person_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppData.I.nickname,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Color(0x33000000), blurRadius: 6),
                            ],
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: .85),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Image.asset(
                      'assets/icon/logo_mark.png',
                      width: 19,
                      color: Colors.white.withValues(alpha: .95),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '人生清单',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.white.withValues(alpha: .9),
                        shadows: const [
                          Shadow(color: Color(0x66000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  s.slogan,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x33000000), blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 18),
                Row(children: [for (final (k, v) in stats) _stat(k, v)]),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withValues(alpha: .3)),
                const SizedBox(height: 12),
                Text(
                  summary,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: .8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _stat(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(right: 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.white.withValues(alpha: .8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
