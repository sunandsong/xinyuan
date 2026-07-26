import 'dart:convert';
import 'package:http/http.dart' as http;

/// 后端配置。cloud = 真连 CloudBase；mock = 指向本地服务器（npm run dev）。
class ApiConfig {
  static const String cloudBase =
      'https://renshengqingdan-d8feva5q55d12bab-1258070735.ap-shanghai.app.tcloudbase.com/api';
  static const String localBase = 'http://127.0.0.1:8787/api';

  // 切到 localBase 即用本地 mock 后端联调（不耗云额度）
  static const String base = cloudBase;
}

class ApiException implements Exception {
  ApiException(this.code, this.message);
  final int code;
  final String message;
  @override
  String toString() => 'ApiException($code, $message)';
}

/// 轻量 API 客户端：自动带 token、解析 JSON、抛出可读错误。
class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  String? token;

  Map<String, String> _headers() => {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _do(
      Future<http.Response> Function() send) async {
    late http.Response r;
    try {
      r = await send().timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ApiException(0, '网络异常，请检查网络后重试');
    }
    dynamic body;
    try {
      body = r.body.isEmpty ? {} : jsonDecode(r.body);
    } catch (_) {
      body = {};
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return (body is Map<String, dynamic>) ? body : {'data': body};
    }
    final err = (body is Map && body['error'] is String) ? body['error'] as String : 'error';
    throw ApiException(r.statusCode, _friendly(err));
  }

  String _friendly(String code) {
    switch (code) {
      case 'invalid_email':
        return '邮箱格式不正确';
      case 'weak_password':
        return '密码至少 6 位';
      case 'email_exists':
        return '该邮箱已注册';
      case 'invalid_credentials':
        return '邮箱或密码错误';
      case 'unauthorized':
        return '登录已过期，请重新登录';
      default:
        return code;
    }
  }

  Future<Map<String, dynamic>> get(String path) =>
      _do(() => http.get(Uri.parse('${ApiConfig.base}$path'), headers: _headers()));

  Future<Map<String, dynamic>> post(String path, Object? body) => _do(() =>
      http.post(Uri.parse('${ApiConfig.base}$path'),
          headers: _headers(), body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> patch(String path, Object? body) => _do(() =>
      http.patch(Uri.parse('${ApiConfig.base}$path'),
          headers: _headers(), body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> delete(String path) =>
      _do(() => http.delete(Uri.parse('${ApiConfig.base}$path'), headers: _headers()));
}

/// 账号相关接口
class AuthApi {
  static Future<Map<String, dynamic>> register(String email, String password,
      {String? nickname}) {
    return ApiClient.I.post('/auth/register', {
      'email': email,
      'password': password,
      if (nickname != null) 'nickname': nickname,
    });
  }

  static Future<Map<String, dynamic>> login(String email, String password) {
    return ApiClient.I.post('/auth/login', {'email': email, 'password': password});
  }

  static Future<Map<String, dynamic>> me() => ApiClient.I.get('/me');

  static Future<void> deleteAccount() async {
    await ApiClient.I.delete('/auth/account');
  }
}
