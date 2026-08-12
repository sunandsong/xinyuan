import 'dart:convert';
import 'package:http/http.dart' as http;

/// 后端配置：只连 CloudBase，数据全部上云。
class ApiConfig {
  static const String cloudBase =
      'https://renshengqingdan-d8feva5q55d12bab-1258070735.ap-shanghai.app.tcloudbase.com/api';
  // 默认打线上；本地起 backend 的 npm run dev 时（它也是读写同一个云环境）：
  //   flutter run --dart-define=API_BASE=http://127.0.0.1:8787/api
  static const String base = String.fromEnvironment(
    'API_BASE',
    defaultValue: cloudBase,
  );
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

  /// 底层 http 客户端；测试里换成 MockClient 就能在不联网的情况下跑同步逻辑
  static http.Client http_ = http.Client();

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
      case 'invalid_account':
        return '账号需 3-20 位字母、数字或下划线';
      case 'weak_password':
        return '密码至少 6 位';
      case 'account_exists':
        return '该账号已注册';
      case 'invalid_credentials':
        return '账号或密码错误';
      case 'unauthorized':
        return '登录已过期，请重新登录';
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
      case 'content_required':
        return '写点内容再提交吧';
      case 'banned':
        return '账号已被封禁，如有疑问请通过意见反馈联系我们';
      default:
        return code;
    }
  }

  Future<Map<String, dynamic>> get(String path) => _do(
    () => http_.get(Uri.parse('${ApiConfig.base}$path'), headers: _headers()),
  );

  Future<Map<String, dynamic>> post(String path, Object? body) => _do(
    () => http_.post(
      Uri.parse('${ApiConfig.base}$path'),
      headers: _headers(),
      body: jsonEncode(body ?? {}),
    ),
  );

  Future<Map<String, dynamic>> patch(String path, Object? body) => _do(
    () => http_.patch(
      Uri.parse('${ApiConfig.base}$path'),
      headers: _headers(),
      body: jsonEncode(body ?? {}),
    ),
  );

  Future<Map<String, dynamic>> delete(String path) => _do(
    () =>
        http_.delete(Uri.parse('${ApiConfig.base}$path'), headers: _headers()),
  );
}

/// 账号相关接口
class AuthApi {
  static Future<Map<String, dynamic>> register(
    String account,
    String password, {
    String? nickname,
  }) {
    return ApiClient.I.post('/auth/register', {
      'account': account,
      'password': password,
      if (nickname != null) 'nickname': nickname,
    });
  }

  static Future<Map<String, dynamic>> login(
    String account,
    String password, {
    String? device,
    String? os,
    String? appVersion,
  }) {
    return ApiClient.I.post('/auth/login', {
      'account': account,
      'password': password,
      if (device != null) 'device': device,
      if (os != null) 'os': os,
      if (appVersion != null) 'appVersion': appVersion,
    });
  }

  static Future<Map<String, dynamic>> me() => ApiClient.I.get('/me');

  static Future<Map<String, dynamic>> updateProfile({
    String? nickname,
    String? avatarUrl,
    Map<String, int>? achievements,
    Map<String, int>? checkins,
    String? gender,
    String? birthday,
  }) {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    if (achievements != null) body['achievements'] = achievements;
    if (checkins != null) body['checkins'] = checkins;
    if (gender != null) body['gender'] = gender;
    if (birthday != null) body['birthday'] = birthday;
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
    Map<String, dynamic>? profile,
  }) {
    return ApiClient.I.post('/sync/push', {
      if (wishes != null) 'wishes': wishes,
      if (tasks != null) 'tasks': tasks,
      if (letters != null) 'letters': letters,
      if (profile != null) 'profile': profile,
    });
  }
}

/// 排行榜接口
class RankApi {
  /// [by] = wish（心愿实现数）| task（任务完成数）| achv（奖杯数）| place（地图点亮数）
  static Future<Map<String, dynamic>> top(String by) =>
      ApiClient.I.get('/leaderboard?by=$by');

  /// 排行榜点进详情用：昵称/头像/性别 + 四项统计与名次 + 已解锁勋章
  static Future<Map<String, dynamic>> userProfile(String uid) =>
      ApiClient.I.get('/users/$uid');

  /// 内容榜：哪个心愿被最多人完成过（跨全部用户统计标题，不看是谁）
  static Future<Map<String, dynamic>> topWishes() =>
      ApiClient.I.get('/insights/wishes');

  /// 内容榜：哪个景点被最多人打卡过
  static Future<Map<String, dynamic>> topSpots() =>
      ApiClient.I.get('/insights/places');

  /// 心愿详情页：这个标题多少人也想做/已实现（不含自己）
  static Future<Map<String, dynamic>> wishStats(String title) => ApiClient.I
      .get('/insights/wishes/stats?title=${Uri.encodeQueryComponent(title)}');

  /// 内容榜穿透：谁完成过这个心愿
  static Future<Map<String, dynamic>> wishCompleters(String title) => ApiClient
      .I
      .get('/insights/wishes/users?title=${Uri.encodeQueryComponent(title)}');

  /// 内容榜穿透：谁打卡过这个景点
  static Future<Map<String, dynamic>> placeVisitors(String place) => ApiClient.I
      .get('/insights/places/users?place=${Uri.encodeQueryComponent(place)}');
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

/// App 配置下发：登录后一次性拉走公告/最低版本等（内容表数据 App 有内置兜底，暂不消费）
class ConfigApi {
  static Future<Map<String, dynamic>> fetch() => ApiClient.I.get('/config');
}

/// 行为埋点：批量上报，一次最多 50 条，服务端写失败也不影响返回
class EventsApi {
  static Future<void> track(List<Map<String, dynamic>> events) =>
      ApiClient.I.post('/events', {'events': events});
}

/// 意见反馈：存进后端 feedback 表，人工看，不用额外接客服系统
class FeedbackApi {
  static Future<void> submit(String content) =>
      ApiClient.I.post('/feedback', {'content': content});
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
