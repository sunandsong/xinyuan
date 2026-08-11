import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data.dart';
import 'pages/splash_page.dart';
import 'theme.dart';
import 'ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppData.I.initSession();
  _installFrameWatchdog();
  runApp(const XinyuanApp());
}

/// iOS 偶发引擎竞态：键盘收起 + 弹窗转场同帧爆发时，vsync 请求会被吞掉——
/// 帧已排队（hasScheduledFrame=true）却再也不渲染，画面永久定格。
/// 用户看到的就是「登录后卡在请稍候」，实际登录早已成功。
/// 兜底：发现排了帧却超过 1 秒没出帧，就强制渲染一帧把管线踢活。
/// 正常运行时条件永远不成立，零开销。
void _installFrameWatchdog() {
  var last = DateTime.now();
  WidgetsBinding.instance.addPersistentFrameCallback(
    (_) => last = DateTime.now(),
  );
  Timer.periodic(const Duration(seconds: 1), (_) {
    if (WidgetsBinding.instance.hasScheduledFrame &&
        DateTime.now().difference(last) > const Duration(seconds: 1)) {
      WidgetsBinding.instance.scheduleForcedFrame();
    }
  });
}

class XinyuanApp extends StatelessWidget {
  const XinyuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '人生清单',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: T.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: T.accent),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        fontFamily: 'MiSans',
        fontFamilyFallback: const ['PingFang SC', 'sans-serif'],
        // 日期选择器：整体白底墨字，选中日期用深色圆底，不出现主题绿
        datePickerTheme: DatePickerThemeData(
          backgroundColor: T.card,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: T.card,
          headerForegroundColor: T.ink,
          dividerColor: T.line,
          dayForegroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? Colors.white : T.ink,
          ),
          dayBackgroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? T.ink : null,
          ),
          dayOverlayColor: const WidgetStatePropertyAll(T.field),
          todayForegroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? Colors.white : T.ink,
          ),
          todayBackgroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? T.ink : null,
          ),
          todayBorder: const BorderSide(color: T.muted),
          yearForegroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? Colors.white : T.ink,
          ),
          yearBackgroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? T.ink : null,
          ),
          weekdayStyle: const TextStyle(color: T.muted),
          confirmButtonStyle: TextButton.styleFrom(foregroundColor: T.ink),
          cancelButtonStyle: TextButton.styleFrom(foregroundColor: T.muted),
        ),
      ),
      builder: (context, child) => tabletTextScale(context, child),
      home: const SplashPage(),
    );
  }
}
