import 'dart:convert';
import 'package:http/http.dart' as http;

/// 后端配置。cloud = 真连 CloudBase；mock = 指向本地服务器（npm run dev）。
class ApiConfig {
  static const String cloudBase =
      'https://renshengqingdan-d8feva5q55d12bab-1258070735.ap-shanghai.app.tcloudbase.com/api';
  static const String localBase = 'http://127.0.0.1:8799/api';

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
    Future<http.Response> Function() send,
  ) async {
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
    // 413 是网关本身拒绝的（请求体过大），响应体不是我们自己的 {error} 格式
    if (r.statusCode == 413) {
      throw ApiException(413, '内容太多，请精简后重试');
    }
    final err = (body is Map && body['error'] is String)
        ? body['error'] as String
        : null;
    throw ApiException(
      r.statusCode,
      err != null ? _friendly(err) : '网络异常，请稍后重试',
    );
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
      case 'code_required':
        return '请输入验证码';
      case 'code_expired':
        return '验证码已过期，请重新获取';
      case 'invalid_code':
        return '验证码不正确';
      case 'code_too_many_attempts':
        return '验证码错误次数过多，请重新获取';
      case 'code_rate_limited':
        return '发送太频繁，请稍后再试';
      case 'nothing_to_update':
        return '没有可更新的内容';
      case 'too_many_items':
        return '本次同步内容过多';
      case 'wishId_and_title_required':
        return '缺少心愿信息，无法生成分享';
      case 'not_found':
        return '内容不存在或已失效';
      case 'unsupported_type':
        return '这种图片格式暂不支持';
      default:
        return code;
    }
  }

  Future<Map<String, dynamic>> get(String path) => _do(
    () => http.get(Uri.parse('${ApiConfig.base}$path'), headers: _headers()),
  );

  Future<Map<String, dynamic>> post(String path, Object? body) => _do(
    () => http.post(
      Uri.parse('${ApiConfig.base}$path'),
      headers: _headers(),
      body: jsonEncode(body ?? {}),
    ),
  );

  Future<Map<String, dynamic>> patch(String path, Object? body) => _do(
    () => http.patch(
      Uri.parse('${ApiConfig.base}$path'),
      headers: _headers(),
      body: jsonEncode(body ?? {}),
    ),
  );

  Future<Map<String, dynamic>> delete(String path) => _do(
    () => http.delete(Uri.parse('${ApiConfig.base}$path'), headers: _headers()),
  );
}

/// 账号相关接口
class AuthApi {
  static Future<Map<String, dynamic>> sendCode(
    String email, {
    String purpose = 'register',
  }) {
    return ApiClient.I.post('/auth/send-code', {
      'email': email,
      'purpose': purpose,
    });
  }

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String code, {
    String? nickname,
  }) {
    return ApiClient.I.post('/auth/register', {
      'email': email,
      'password': password,
      'code': code,
      if (nickname != null) 'nickname': nickname,
    });
  }

  static Future<Map<String, dynamic>> login(String email, String password) {
    return ApiClient.I.post('/auth/login', {
      'email': email,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> me() => ApiClient.I.get('/me');

  static Future<Map<String, dynamic>> updateProfile({
    String? nickname,
    String? avatarEmoji,
    bool clearEmoji = false,
  }) {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (clearEmoji) {
      body['avatarEmoji'] = null;
    } else if (avatarEmoji != null) {
      body['avatarEmoji'] = avatarEmoji;
    }
    return ApiClient.I.patch('/me', body);
  }

  static Future<void> deleteAccount() async {
    await ApiClient.I.delete('/auth/account');
  }
}

/// 心愿/任务/时光胶囊云同步接口（增量拉取 / 批量上传，LWW）
class SyncApi {
  static Future<Map<String, dynamic>> pull(int since) =>
      ApiClient.I.get('/sync/pull?since=$since');

  static Future<Map<String, dynamic>> push({
    List<Map<String, dynamic>>? wishes,
    List<Map<String, dynamic>>? tasks,
    List<Map<String, dynamic>>? letters,
  }) {
    return ApiClient.I.post('/sync/push', {
      if (wishes != null) 'wishes': wishes,
      if (tasks != null) 'tasks': tasks,
      if (letters != null) 'letters': letters,
    });
  }
}

/// 心愿分享短码接口
class ShareApi {
  static Future<Map<String, dynamic>> create({
    required String wishId,
    required String title,
    String? quote,
    String? color,
  }) {
    return ApiClient.I.post('/share', {
      'wishId': wishId,
      'title': title,
      if (quote != null) 'quote': quote,
      if (color != null) 'color': color,
    });
  }
}

/// 图片直传凭证：云函数网关请求体限得很小（约 100KB），图片本体传不过去，
/// 所以只找后端换一次性凭证，图片字节由客户端直接 PUT 给云存储
class UploadApi {
  static Future<UploadTicket> ticket({required String mime}) async {
    final r = await ApiClient.I.post('/upload', {'mime': mime});
    return UploadTicket(
      url: r['url'] as String? ?? '',
      headers:
          (r['headers'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
      downloadUrl: r['downloadUrl'] as String? ?? '',
    );
  }
}

class UploadTicket {
  UploadTicket({
    required this.url,
    required this.headers,
    required this.downloadUrl,
  });
  final String url;
  final Map<String, String> headers;
  final String downloadUrl;
}
