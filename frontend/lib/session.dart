import 'package:shared_preferences/shared_preferences.dart';
import 'api/api.dart';

/// 本地会话持久化：token / 邮箱 / 昵称。
class Session {
  static const _kToken = 'auth_token';
  static const _kEmail = 'auth_email';
  static const _kNick = 'auth_nick';

  /// 启动时调用：把本地 token 装回 ApiClient
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    ApiClient.I.token = p.getString(_kToken);
  }

  static Future<void> save({
    required String token,
    String? email,
    String? nick,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    if (email != null) await p.setString(_kEmail, email);
    if (nick != null) await p.setString(_kNick, nick);
    ApiClient.I.token = token;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kEmail);
    await p.remove(_kNick);
    ApiClient.I.token = null;
  }

  static Future<String?> email() async =>
      (await SharedPreferences.getInstance()).getString(_kEmail);
  static Future<String?> nick() async =>
      (await SharedPreferences.getInstance()).getString(_kNick);
  static bool get isLoggedIn => ApiClient.I.token != null;
}
