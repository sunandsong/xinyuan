import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'crash_reporter.dart';
import 'theme.dart';
import 'ui.dart';

/// 隐私合规同意状态：本地预览模式（未登录、不联网、不采集）永远不需要它；
/// 但凡涉及联网上传（登录/注册、崩溃上报联网发送）之前，必须先过这一道。
/// 不同意就退回本地预览，App 不因此崩溃或强制退出。
class ConsentState {
  ConsentState._();
  static final ConsentState I = ConsentState._();

  static const _key = 'privacy_consented_v1';
  bool _consented = false;
  bool get consented => _consented;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _consented = p.getBool(_key) ?? false;
    } catch (_) {
      _consented = false;
    }
  }

  Future<void> _grant() async {
    _consented = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, true);
    } catch (_) {}
  }
}

/// 确保拿到用户同意：已经同意过直接放行；没同意过就弹不可外部点掉的合规弹窗，
/// 用户选"同意"才返回 true。同意后顺带把本地攒着还没发的崩溃现场补发一次。
Future<bool> ensureConsent(BuildContext context) async {
  if (ConsentState.I.consented) return true;
  final ok = await showBlurDialog<bool>(
    context,
    const _ConsentDialog(),
    barrierDismissible: false,
  );
  if (ok == true) {
    await ConsentState.I._grant();
    unawaited(CrashReporter.I.flush());
    return true;
  }
  return false;
}

class _ConsentDialog extends StatelessWidget {
  const _ConsentDialog();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '使用前请阅读',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 13.5, color: T.ink, height: 1.6),
            children: [
              const TextSpan(
                text: '继续使用登录、云同步等联网功能前，请先阅读并同意我们的',
              ),
              TextSpan(
                text: '《用户协议》',
                style: const TextStyle(color: T.accent, fontWeight: FontWeight.w600),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => openLegalPage('/terms'),
              ),
              const TextSpan(text: '和'),
              TextSpan(
                text: '《隐私政策》',
                style: const TextStyle(color: T.accent, fontWeight: FontWeight.w600),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => openLegalPage('/privacy'),
              ),
              const TextSpan(
                text: '。不同意也可以继续在本地预览人生清单模板，不会联网、不会采集任何信息。',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BigBtn('同意并继续', onTap: () => Navigator.of(context).pop(true)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(false),
          child: const Text(
            '不同意，仅本地使用',
            style: TextStyle(fontSize: 13.5, color: T.faint),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
