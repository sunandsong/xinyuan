import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data.dart';
import 'pages/splash_page.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppData.I.initSession();
  runApp(const XinyuanApp());
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
      ),
      home: const SplashPage(),
    );
  }
}
