import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'theme.dart';

/// 列表错峰入场 —— 逐条淡入 + 上滑
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  @override
  void initState() {
    super.initState();
    Future.delayed(
        Duration(milliseconds: 40 + widget.index * 45), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0, .08), end: Offset.zero)
            .animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// 在指定屏幕位置迸发彩色粒子（勾选庆祝）
void burstAt(BuildContext context, Offset globalPos, Color color) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Burst(
      position: globalPos,
      color: color,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _Burst extends StatefulWidget {
  const _Burst(
      {required this.position, required this.color, required this.onDone});
  final Offset position;
  final Color color;
  final VoidCallback onDone;
  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750))
    ..forward().whenComplete(widget.onDone);
  late final List<double> _ang =
      List.generate(12, (i) => i * math.pi / 6 + math.pi / 12);
  late final List<double> _spin =
      List.generate(12, (i) => (i.isEven ? 1 : -1) * (2.2 + (i % 4) * 1.1));
  late final List<Color> _colors = _confettiColors(widget.color);

  static List<Color> _confettiColors(Color base) {
    final hsl = HSLColor.fromColor(base);
    return [
      base,
      hsl.withLightness((hsl.lightness + .22).clamp(0.0, 1.0)).toColor(),
      hsl.withHue((hsl.hue + 35) % 360).toColor(),
      const Color(0xFFFFD166), // 金色点缀，让撒纸屑更有节庆感
    ];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_c.value);
            return CustomPaint(
              painter: _BurstPainter(t, _ang, _spin, _colors),
            );
          },
        ),
      ),
    );
  }
}

/// 撒纸屑效果：小方片带旋转迸发，比纯圆点更有庆祝感
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.ang, this.spin, this.colors);
  final double t;
  final List<double> ang;
  final List<double> spin;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final dist = 6 + t * 46;
    final side = (1 - t * .3) * 6.5;
    // 前 75% 时间保持不透明，最后一段快速淡出，比线性淡出更像纸屑飘落消失
    final alpha = t < .75 ? 1.0 : (1 - (t - .75) / .25).clamp(0.0, 1.0);
    for (var i = 0; i < ang.length; i++) {
      final o = Offset(
          math.cos(ang[i]) * dist, math.sin(ang[i]) * dist - t * 12);
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: alpha);
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(spin[i] * t * math.pi);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: side, height: side * .55),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 16)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
}

/// 白色胶囊按钮（顶栏）
class PillBtn extends StatelessWidget {
  const PillBtn({super.key, required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(999),
          boxShadow: T.shadowCard,
        ),
        child: Icon(icon, size: 19, color: const Color(0xFF3A3A42)),
      ),
    );
  }
}

/// 暗色胶囊按钮（高光页）
class DarkPill extends StatelessWidget {
  const DarkPill({super.key, required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFFDCE4F0)),
      ),
    );
  }
}

/// 右上角渐变加号
class PlusBtn extends StatelessWidget {
  const PlusBtn({super.key, this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: T.plusGrad,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Color(0x803EA983), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.add, size: 22, color: Colors.white),
      ),
    );
  }
}

/// 毛玻璃卡片
class SheetCard extends StatelessWidget {
  const SheetCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: .65), width: 1),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14243A66),
                  blurRadius: 20,
                  offset: Offset(0, 10)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 勾选框 —— 对号弹入 + 背景过渡
class Cb extends StatelessWidget {
  const Cb(
      {super.key,
      required this.done,
      this.onTap,
      this.greyWhenDone = false,
      this.burstColor});
  final bool done;
  final VoidCallback? onTap;
  final bool greyWhenDone;
  final Color? burstColor;
  @override
  Widget build(BuildContext context) {
    final fill = done ? (greyWhenDone ? T.grey : T.accent) : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        if (!done && burstColor != null) {
          burstAt(context, d.globalPosition, burstColor!);
        }
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(6.5),
            border:
                done ? null : Border.all(color: const Color(0xFFCACCD6), width: 1.5),
          ),
          child: AnimatedScale(
            scale: done ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 心愿颜色点 —— 带柔和同色光晕
class WDot extends StatelessWidget {
  const WDot(this.color, {super.key, this.size = 9.5, this.glow = true});
  final Color color;
  final double size;
  final bool glow;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: .45),
                      blurRadius: 5,
                      spreadRadius: -.5),
                ]
              : null,
        ),
      );
}

/// 列表行按压反馈 —— 按下柔和背景高亮
class TapRow extends StatefulWidget {
  const TapRow({super.key, required this.child, this.onTap, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  @override
  State<TapRow> createState() => _TapRowState();
}

class _TapRowState extends State<TapRow> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: widget.padding ?? EdgeInsets.zero,
        decoration: BoxDecoration(
          color: _down ? T.field : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: widget.child,
      ),
    );
  }
}

/// 大按钮
class BigBtn extends StatelessWidget {
  const BigBtn(this.text,
      {super.key, this.onTap, this.gradient, this.bg, this.fg});
  final String text;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? bg;
  final Color? fg;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: gradient == null ? (bg ?? T.accent) : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(text,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: fg ?? Colors.white)),
      ),
    );
  }
}

/// 底部弹层外壳（灰幕 + 圆角抽屉 + 把手）
Future<void> showAppSheet(BuildContext context, Widget child) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x571C1C21),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        decoration: const BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDEDFE5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    ),
  );
}

/// 居中弹层外壳（背景高斯模糊 + 居中白卡），用于登录等需要专注的场景
Future<void> showBlurDialog(BuildContext context, Widget child) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withValues(alpha: .18),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) => Material(
      type: MaterialType.transparency,
      child: Builder(builder: (context) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                decoration: BoxDecoration(
                  color: T.card,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: T.shadowCard,
                ),
                child: child,
              ),
            ),
          ),
        );
      }),
    ),
    transitionBuilder: (context, anim, __, dialogChild) => BackdropFilter(
      filter: ImageFilter.blur(
          sigmaX: 18 * anim.value, sigmaY: 18 * anim.value),
      child: FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: .94, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
          child: dialogChild,
        ),
      ),
    ),
  );
}

/// 小图标按钮（用于工具栏按钮）
Widget toolIconBtn(IconData icon, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration:
          BoxDecoration(color: T.field, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 19, color: T.muted),
    ),
  );
}

/// 输入框样式
InputDecoration fieldDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: T.faint, fontSize: 18),
      filled: true,
      fillColor: T.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide.none,
      ),
    );

/// 选择 chip
class SelChip extends StatelessWidget {
  const SelChip({
    super.key,
    required this.label,
    required this.selected,
    this.dot,
    this.onTap,
  });
  final String label;
  final bool selected;
  final Color? dot;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? T.accentSoft : T.field,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              WDot(dot!, size: 8),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? T.accent : const Color(0xFF3A3A42),
                )),
          ],
        ),
      ),
    );
  }
}
