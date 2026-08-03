// 云同步单测：推送分块 / 失败重排队 / 拉取合并。
// 用 MockClient 顶掉真实网络，不打云端、不耗额度。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinyuan/api/api.dart';
import 'package:xinyuan/data.dart';

/// http.Response(String) 走 Latin-1 编码，中文会直接抛异常，必须自己按 UTF-8 出字节
http.Response _json(Map<String, dynamic> body, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), code,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// 记下每一个发出去的请求，供断言用
class _Recorder {
  final requests = <http.Request>[];

  /// 每次 /sync/pull 请求带的 since，用来验证增量拉取真的生效
  final pulledSince = <int>[];

  /// [pull] 是首次 /sync/pull 的返回；[nextPull] 是第二次起的返回（测增量用）；
  /// [failPush] 为真时所有推送都 500
  MockClient client({
    Map<String, dynamic>? pull,
    Map<String, dynamic>? nextPull,
    bool failPush = false,
  }) {
    return MockClient((req) async {
      requests.add(req);
      final path = req.url.path;
      if (path.endsWith('/sync/push')) {
        return failPush
            ? _json({'error': 'boom'}, 500)
            : _json({'accepted': true});
      }
      if (path.endsWith('/sync/pull')) {
        pulledSince.add(int.parse(req.url.queryParameters['since'] ?? '-1'));
        final n = pulledSince.length;
        return _json((n > 1 ? nextPull : null) ?? pull ?? {'now': 0});
      }
      if (path.endsWith('/auth/login') || path.endsWith('/auth/register')) {
        return _json({
          'token': 'test-token',
          'profile': {'nickname': '松之', 'createdAt': 1730000000000},
        });
      }
      return _json(const {});
    });
  }

  List<http.Request> get pushes =>
      requests.where((r) => r.url.path.endsWith('/sync/push')).toList();
}

Map<String, dynamic> _wish(String id, String title,
        {int updatedAt = 1000, bool deleted = false}) =>
    {
      '_id': id,
      'title': title,
      'color': 'E05A5A',
      'createdAt': 1000,
      'updatedAt': updatedAt,
      'deleted': deleted,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final d = AppData.I;
  late _Recorder rec;

  setUp(() {
    rec = _Recorder();
    d.wishes.clear();
    d.tasks.clear();
    d.letters.clear();
    d.achvUnlocked.clear();
  });

  tearDown(() => ApiClient.http_ = http.Client());

  /// 等推送防抖（300ms）跑完
  Future<void> waitFlush() =>
      Future<void>.delayed(const Duration(milliseconds: 450));

  const red = Color(0xFFE05A5A);

  group('推送', () {
    // 只有登录状态才往云上推（未登录纯本地用，见 _touchWish）
    setUp(() => d.signedIn = true);
    tearDown(() => d.signedIn = false);

    test('少量改动合成一次请求', () async {
      ApiClient.http_ = rec.client();
      d.addWish('跑完五公里', red);
      d.addTask('晨跑', DateTime.now());
      await waitFlush();

      expect(rec.pushes.length, 1, reason: '防抖应把连续改动并成一次');
      final body = jsonDecode(rec.pushes.single.body) as Map<String, dynamic>;
      expect((body['wishes'] as List).length, 1);
      expect((body['tasks'] as List).length, 1);
    });

    test('超过 80KB 自动切块，每块都在网关 100KB 限制内', () async {
      ApiClient.http_ = rec.client();
      // 每条心愿塞 ~10KB 描述，20 条 ≈ 200KB，必须切成 3 块以上
      final fat = 'x' * 10000;
      for (var i = 0; i < 20; i++) {
        d.addWish('心愿$i', red, desc: fat);
      }
      await waitFlush();

      expect(rec.pushes.length, greaterThan(2), reason: '200KB 不该一次发出去');
      for (final r in rec.pushes) {
        expect(utf8.encode(r.body).length, lessThan(100 * 1024),
            reason: '单次请求体必须小于网关上限，否则整批被 413 拒掉');
      }
      // 一条都不能漏
      final sent = rec.pushes
          .map((r) => jsonDecode(r.body) as Map<String, dynamic>)
          .expand((b) => (b['wishes'] as List? ?? []))
          .length;
      expect(sent, 20);
    });

    test('推送失败：改动放回队列，下次改动时连旧的一起重推', () async {
      ApiClient.http_ = rec.client(failPush: true);
      d.addWish('会失败的', red);
      await waitFlush();
      expect(rec.pushes.length, 1);

      // 换成会成功的客户端，再动一条数据触发下一次推送
      final ok = _Recorder();
      ApiClient.http_ = ok.client();
      d.addWish('新的', red);
      await waitFlush();

      final body = jsonDecode(ok.pushes.single.body) as Map<String, dynamic>;
      final titles =
          (body['wishes'] as List).map((w) => w['title']).toList();
      expect(titles, containsAll(['会失败的', '新的']),
          reason: '上次没推成功的不能丢，要跟着下次一起走');
    });

    test('没有改动就不发请求', () async {
      ApiClient.http_ = rec.client();
      await waitFlush();
      expect(rec.pushes, isEmpty);
    });
  });

  group('拉取', () {
    /// 登录一次并触发 _pullFromCloud
    Future<void> login({Map<String, dynamic>? pull}) async {
      ApiClient.http_ = rec.client(pull: pull);
      await d.loginOrRegister('songzhang', 'pw123456');
    }

    test('云端标记删除的记录不会被拉回本地', () async {
      await login(pull: {
        'now': 1,
        'wishes': [
          {
            '_id': 'w1',
            'title': '活着的心愿',
            'color': 'E05A5A',
            'createdAt': 1730000000000,
            'updatedAt': 1730000000000,
          },
          {
            '_id': 'w2',
            'title': '已删的心愿',
            'color': 'E05A5A',
            'deleted': true,
            'createdAt': 1730000000000,
            'updatedAt': 1730000000000,
          },
        ],
      });

      expect(d.wishes.map((w) => w.title), ['活着的心愿'],
          reason: '带 deleted 标记的不该复活');
    });

    test('登录老账号：云端没数据就是空列表，不本地伪造心愿', () async {
      await login(pull: {'now': 1, 'wishes': []});
      expect(d.wishes, isEmpty, reason: '老账号自己清空的清单不该被偷偷填回来');
    });

    test('新注册账号：自动播 50 条人生清单，并且真的推送上云', () async {
      ApiClient.http_ = rec.client(pull: {'now': 1, 'wishes': []});
      d.signedIn = false;
      await d.loginOrRegister('newbie', 'pw123456', register: true);

      expect(d.wishes.length, 50, reason: '新账号开箱就该有一份清单');
      expect(d.wishes.first.title, isNotEmpty);

      // 等防抖推送，确认这 50 条是真上了云，不是只存在本地
      await waitFlush();
      final sent = rec.pushes
          .map((r) => jsonDecode(r.body) as Map<String, dynamic>)
          .expand((b) => (b['wishes'] as List? ?? []))
          .length;
      expect(sent, 50, reason: '播下的心愿必须同步到云端，否则就是假数据');
      d.signedIn = false;
    });

    test('成就：本地和云端取并集，本地独有的会回推给云端', () async {
      d.achvUnlocked['初试身手'] = 1730000000000;
      await login(pull: {
        'now': 1,
        'wishes': [],
        'profile': {
          'nickname': '松之',
          'createdAt': 1730000000000,
          'achievements': {'首愿达成': 1740000000000},
        },
      });

      expect(d.achvUnlocked.keys, containsAll(['初试身手', '首愿达成']),
          reason: '两边的成就都要留着，拿到即永久');
      expect(d.nickname, '松之');
      expect(d.accountCreatedAt, isNotNull);
    });

    test('注销账号后回到未登录预览态：清会话、清成就、清云端数据', () async {
      await login(pull: {
        'now': 1,
        'wishes': [
          {
            '_id': 'w1',
            'title': '云端来的',
            'color': 'E05A5A',
            'createdAt': 1730000000000,
            'updatedAt': 1730000000000,
          },
        ],
        'profile': {
          'nickname': '松之',
          'createdAt': 1730000000000,
          'achievements': {'初试身手': 1730000000000},
        },
      });
      expect(d.signedIn, isTrue);
      expect(d.achvUnlocked, isNotEmpty);

      await d.deleteAccountRemote();

      expect(d.signedIn, isFalse, reason: '注销后必须回到未登录，逼着重新登录');
      expect(d.account, isNull);
      expect(d.achvUnlocked, isEmpty);
      expect(d.accountCreatedAt, isNull);
      expect(d.wishes.map((w) => w.title), isNot(contains('云端来的')),
          reason: '老账号的云端数据必须清干净');
      expect(d.wishes.length, 50, reason: '回到未登录预览态');
    });

    test('增量拉取：第二次只从上次的时间戳往后拉，本地已有的不动', () async {
      SharedPreferences.setMockInitialValues({});
      ApiClient.http_ = rec.client(
        pull: {
          'now': 1000,
          'wishes': [
            _wish('w1', '留着的'),
            _wish('w2', '会被改的'),
            _wish('w3', '会被删的'),
          ],
        },
        nextPull: {
          'now': 2000,
          'wishes': [
            _wish('w2', '改过的标题', updatedAt: 1500),
            _wish('w3', '会被删的', deleted: true),
            _wish('w4', '新来的', updatedAt: 1500),
          ],
        },
      );

      // 首次登录：全量
      await d.loginOrRegister('songzhang', 'pw123456');
      expect(rec.pulledSince, [0]);
      expect(d.wishes.length, 3);

      // 再次启动：增量
      await d.initSession();
      expect(rec.pulledSince, [0, 1000], reason: '第二次必须带上次的时间戳，不能再从 0 全量拉');

      final titles = d.wishes.map((w) => w.title).toList();
      expect(titles, contains('留着的'), reason: '没变的记录本地留着，不重复拉');
      expect(titles, contains('改过的标题'), reason: '变了的就地替换');
      expect(titles, contains('新来的'));
      expect(titles, isNot(contains('会被删的')), reason: 'deleted 标记要真的删掉');
      expect(d.wishes.length, 3);

      // 顺序没被打乱：改过的还在原位
      expect(d.wishes[1].title, '改过的标题', reason: '就地替换，不能让改过的跳到末尾');
    });

    test('拉取失败不清空本地数据，也不阻断登录', () async {
      d.addWish('本地的心愿', red);
      ApiClient.http_ = MockClient((req) async =>
          req.url.path.endsWith('/auth/login')
              ? _json({'token': 't'})
              : _json({'error': 'server_down'}, 500));

      await d.loginOrRegister('songzhang', 'pw123456');
      expect(d.signedIn, isTrue, reason: '拉取挂了也得让人先进去');
      expect(d.wishes.map((w) => w.title), contains('本地的心愿'));
    });
  });
}
