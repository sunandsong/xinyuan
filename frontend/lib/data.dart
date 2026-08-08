import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'api/api.dart';
import 'pages/tree_page.dart' show achvSlugByName;
import 'pages/world_page.dart' show litPlaceCount;
import 'presets.dart';
import 'session.dart';
import 'theme.dart';

String _hex(Color c) =>
    (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
Color _colorFromHex(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
String _dayStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime _dayParse(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

int _ms(DateTime d) => d.millisecondsSinceEpoch;
DateTime _fromMs(num? ms) => ms == null
    ? DateTime.now()
    : DateTime.fromMillisecondsSinceEpoch(ms.toInt());

DateTime dOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String md(DateTime d) => '${d.month}月${d.day}日';
String ymDots(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}';
String ymdDots(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
const weekNames = ['日', '一', '二', '三', '四', '五', '六'];
String weekLabel(DateTime d) => '周${weekNames[d.weekday % 7]}';

/// 少量节日，仅做日历点缀
const holidays = {
  '1-1': '元旦',
  '5-1': '劳动节',
  '6-1': '儿童节',
  '7-1': '建党节',
  '8-1': '建军节',
  '10-1': '国庆',
};

/// 心愿里程碑：把一个大心愿拆成几步，一步步勾掉
class WishStep {
  WishStep({
    required this.id,
    required this.title,
    this.done = false,
    this.doneAt,
  });
  final String id;
  String title;
  bool done;
  DateTime? doneAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'done': done,
    'doneAt': doneAt == null ? null : _ms(doneAt!),
  };

  factory WishStep.fromJson(Map<String, dynamic> j) => WishStep(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    done: j['done'] as bool? ?? false,
    doneAt: j['doneAt'] == null ? null : _fromMs(j['doneAt'] as num),
  );
}

/// 心愿笔记：带时间戳的一句话，记录推进过程
class WishNote {
  WishNote({required this.id, required this.text, required this.at});
  final String id;
  String text;
  DateTime at;

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'at': _ms(at)};

  factory WishNote.fromJson(Map<String, dynamic> j) => WishNote(
    id: j['id'] as String? ?? '',
    text: j['text'] as String? ?? '',
    at: _fromMs(j['at'] as num?),
  );
}

class Wish {
  Wish({
    required this.id,
    required this.title,
    required this.color,
    required this.createdAt,
    DateTime? updatedAt,
    this.done = false,
    this.doneAt,
    this.quote,
    this.location,
    this.heroIndex,
    this.desc,
    this.targetAt,
    List<WishStep>? steps,
    List<WishNote>? notes,
    List<String>? photos,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? createdAt,
       steps = steps ?? [],
       notes = notes ?? [],
       photos = photos ?? [];
  final String id;
  String title;
  Color color;
  bool done;
  DateTime createdAt;
  DateTime updatedAt; // 供云端 LWW 冲突判断
  DateTime? doneAt;
  String? quote;
  String? location;
  int? heroIndex; // 凭证照片渐变的下标（没有真实照片时的兜底）
  String? desc; // 描述
  DateTime? targetAt; // 想在这天之前做到（可空）
  List<WishStep> steps; // 里程碑
  List<WishNote> notes; // 过程笔记，新的在前
  List<String> photos; // 真实照片（云存储 fileID / https 链接）
  bool deleted;

  List<Color>? get hero => heroIndex == null
      ? null
      : AppData.heroes[heroIndex! % AppData.heroes.length];

  int get doneStepCount => steps.where((s) => s.done).length;

  /// 里程碑完成比例；没有里程碑时返回 null（调用方自己决定要不要显示进度）
  double? get stepProgress =>
      steps.isEmpty ? null : doneStepCount / steps.length;

  /// 距目标日期还有几天：正数=还剩，负数=已超期，null=没设
  int? get daysToTarget => targetAt == null
      ? null
      : dOnly(targetAt!).difference(dOnly(DateTime.now())).inDays;

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'color': _hex(color),
    'desc': desc,
    'done': done,
    'doneAt': doneAt == null ? null : _ms(doneAt!),
    'quote': quote,
    'location': location,
    'heroIndex': heroIndex,
    'targetAt': targetAt == null ? null : _ms(targetAt!),
    'steps': [for (final s in steps) s.toJson()],
    'notes': [for (final n in notes) n.toJson()],
    'photos': photos,
    'createdAt': _ms(createdAt),
    'updatedAt': _ms(updatedAt),
    'deleted': deleted,
  };

  factory Wish.fromJson(Map<String, dynamic> j) => Wish(
    id: j['_id'] as String,
    title: j['title'] as String? ?? '',
    color: _colorFromHex(j['color'] as String? ?? 'A8B8F8'),
    createdAt: _fromMs(j['createdAt'] as num?),
    updatedAt: _fromMs(j['updatedAt'] as num?),
    done: j['done'] as bool? ?? false,
    doneAt: j['doneAt'] == null ? null : _fromMs(j['doneAt'] as num),
    quote: j['quote'] as String?,
    location: j['location'] as String?,
    heroIndex: j['heroIndex'] as int?,
    desc: j['desc'] as String?,
    targetAt: j['targetAt'] == null ? null : _fromMs(j['targetAt'] as num),
    // 老数据没有这三个字段，一律兜底成空列表
    steps: _listOf(j['steps'], WishStep.fromJson),
    notes: _listOf(j['notes'], WishNote.fromJson),
    photos: [for (final p in (j['photos'] as List? ?? const [])) p.toString()],
    deleted: j['deleted'] as bool? ?? false,
  );
}

List<R> _listOf<R>(dynamic raw, R Function(Map<String, dynamic>) from) => [
  for (final e in (raw as List? ?? const []))
    if (e is Map) from(Map<String, dynamic>.from(e)),
];

class Task {
  Task({
    required this.id,
    required this.title,
    required this.day,
    this.wishId,
    this.done = false,
    this.time,
    this.remind = false,
    this.color,
    this.desc,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();
  final String id;
  String title;
  DateTime day;
  String? wishId; // null = 杂事
  bool done;
  String? time; // "HH:mm"，配合 remind 用；没设就提醒默认走 9:00
  bool remind; // 当天要不要发本地提醒
  Color? color; // 任务自身颜色
  String? desc; // 描述
  DateTime createdAt;
  DateTime updatedAt; // 供云端 LWW 冲突判断
  bool deleted;

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'day': _dayStr(day),
    'time': time,
    'remind': remind,
    'done': done,
    'wishId': wishId,
    if (color != null) 'color': _hex(color!),
    'desc': desc,
    'createdAt': _ms(createdAt),
    'updatedAt': _ms(updatedAt),
    'deleted': deleted,
  };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['_id'] as String,
    title: j['title'] as String? ?? '',
    day: _dayParse(j['day'] as String? ?? _dayStr(DateTime.now())),
    wishId: j['wishId'] as String?,
    done: j['done'] as bool? ?? false,
    time: j['time'] as String?,
    remind: j['remind'] as bool? ?? false,
    color: (j['color'] is String && (j['color'] as String).isNotEmpty)
        ? _colorFromHex(j['color'] as String)
        : null,
    desc: j['desc'] as String?,
    createdAt: _fromMs(j['createdAt'] as num?),
    updatedAt: _fromMs(j['updatedAt'] as num?),
    deleted: j['deleted'] as bool? ?? false,
  );
}

/// 时光胶囊：写给未来的信，到指定日期才能开启。
/// 是否已开启是纯派生状态（见 AppData.isLetterOpen），不单独存 opened 字段。
class Letter {
  Letter({
    required this.id,
    required this.title,
    required this.content,
    required this.openAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();
  final String id;
  String title;
  String content;
  DateTime openAt;
  DateTime createdAt;
  DateTime updatedAt;
  bool deleted;

  Map<String, dynamic> toJson() => {
    '_id': id,
    'title': title,
    'content': content,
    'openAt': _ms(openAt),
    'createdAt': _ms(createdAt),
    'updatedAt': _ms(updatedAt),
    'deleted': deleted,
  };

  factory Letter.fromJson(Map<String, dynamic> j) => Letter(
    id: j['_id'] as String,
    title: j['title'] as String? ?? '',
    content: j['content'] as String? ?? '',
    openAt: _fromMs(j['openAt'] as num?),
    createdAt: _fromMs(j['createdAt'] as num?),
    updatedAt: _fromMs(j['updatedAt'] as num?),
    deleted: j['deleted'] as bool? ?? false,
  );
}

/// 全局状态（内存态，无本地磁盘持久化）：数据全部来自后端 API——
/// 启动/登录即整体拉取云端数据，后续每次增删改会防抖批量推送云端；
/// 未登录时「人生清单」显示本地预览（人生必做清单前 50 条，不同步），任务列表为空。
class _PushChunk {
  final wishes = <Wish>[];
  final tasks = <Task>[];
  final letters = <Letter>[];
}

class AppData extends ChangeNotifier with WidgetsBindingObserver {
  AppData._() {
    _seedLifeGoals(); // 未登录时的本地预览，见 _seedLifeGoals 注释
    WidgetsBinding.instance.addObserver(this);
  }
  static final AppData I = AppData._();

  /// App 切后台/被杀前，把还没到防抖时间的改动立刻推一次，别等 800ms
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pushTimer?.cancel();
      _saveCache();
      unawaited(_flushPush());
    }
  }

  final wishes = <Wish>[];
  final tasks = <Task>[];
  final letters = <Letter>[];
  int _idSeq = 0;
  final _rand = Random();
  /// 序号每次启动从 0 重来，只靠「毫秒 + 序号」的话，同一账号两台设备
  /// 都刚启动、同一毫秒建记录就会撞出同一个 id，服务端按 LWW 只留一条，
  /// 另一条无声消失。补一段随机量把这条路堵死。
  String _newId(String prefix) {
    _idSeq++;
    final ms = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final r = _rand.nextInt(1679616).toRadixString(36).padLeft(4, '0'); // 36^4
    return '${prefix}_$ms${_idSeq.toRadixString(36)}$r';
  }

  // 待推送到云端的变更（合并推送，避免批量导入时逐条打接口）
  final Set<Wish> _dirtyWishes = {};
  final Set<Task> _dirtyTasks = {};
  final Set<Letter> _dirtyLetters = {};
  Timer? _pushTimer;

  void _touchWish(Wish w) {
    w.updatedAt = DateTime.now();
    if (!signedIn) return;
    _dirtyWishes.add(w);
    _scheduleFlush();
  }

  void _touchTask(Task t) {
    t.updatedAt = DateTime.now();
    if (!signedIn) return;
    _dirtyTasks.add(t);
    _scheduleFlush();
  }

  void _touchLetter(Letter l) {
    l.updatedAt = DateTime.now();
    if (!signedIn) return;
    _dirtyLetters.add(l);
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _pushTimer?.cancel();
    // 300ms 够合并批量导入这类连续调用了，同时把"改完立刻被杀掉"的风险窗口缩到最小
    _pushTimer = Timer(const Duration(milliseconds: 300), () {
      _saveCache();
      unawaited(_flushPush());
    });
  }

  // 云函数网关单次请求体上限约 100KB，超量的批量改动（比如一次性导入/改一堆任务）
  // 得分批推送，不然整批直接被网关 413 拒掉、还静默吞掉
  static const _pushChunkBudget = 80 * 1024;

  List<_PushChunk> _buildPushChunks(
    List<Wish> ws,
    List<Task> ts,
    List<Letter> ls,
  ) {
    final chunks = <_PushChunk>[];
    var cur = _PushChunk();
    var curSize = 0;
    void add(void Function(_PushChunk) put, int size) {
      if (curSize > 0 && curSize + size > _pushChunkBudget) {
        chunks.add(cur);
        cur = _PushChunk();
        curSize = 0;
      }
      put(cur);
      curSize += size;
    }

    for (final w in ws) {
      add((c) => c.wishes.add(w), utf8.encode(jsonEncode(w.toJson())).length);
    }
    for (final t in ts) {
      add((c) => c.tasks.add(t), utf8.encode(jsonEncode(t.toJson())).length);
    }
    for (final l in ls) {
      add((c) => c.letters.add(l), utf8.encode(jsonEncode(l.toJson())).length);
    }
    if (curSize > 0) chunks.add(cur);
    return chunks;
  }

  Future<void> _flushPush() async {
    if (_dirtyWishes.isEmpty && _dirtyTasks.isEmpty && _dirtyLetters.isEmpty) {
      return;
    }
    final chunks = _buildPushChunks(
      _dirtyWishes.toList(),
      _dirtyTasks.toList(),
      _dirtyLetters.toList(),
    );
    _dirtyWishes.clear();
    _dirtyTasks.clear();
    _dirtyLetters.clear();
    for (var i = 0; i < chunks.length; i++) {
      final c = chunks[i];
      try {
        await SyncApi.push(
          wishes: c.wishes.isEmpty
              ? null
              : c.wishes.map((w) => w.toJson()).toList(),
          tasks: c.tasks.isEmpty
              ? null
              : c.tasks.map((t) => t.toJson()).toList(),
          letters: c.letters.isEmpty
              ? null
              : c.letters.map((l) => l.toJson()).toList(),
          // 计数搭第一批的顺风车上去，排行榜就不用另发请求了
          profile: i == 0 ? rankCounters() : null,
        );
      } catch (e) {
        // 静默失败：把这批和还没发的都放回去，下次该条目再变更（或下次启动）时重推
        for (var j = i; j < chunks.length; j++) {
          _dirtyWishes.addAll(chunks[j].wishes);
          _dirtyTasks.addAll(chunks[j].tasks);
          _dirtyLetters.addAll(chunks[j].letters);
        }
        // 401 单独处理：不是网络抖动，重试也没用，得提示重新登录
        if (e is ApiException && e.code == 401) unawaited(_handleUnauthorized());
        return;
      }
    }
  }

  /// 排行榜用的 4 个计数。跟着同步推送一起上传，不额外发请求。
  Map<String, dynamic> rankCounters() => {
        'doneCount': wishes.where((w) => w.done).length,
        'taskCount': tasks.where((t) => t.done).length,
        'achvCount': achvUnlocked.length,
        'placeCount': litPlaceCount(),
      };

  /// 把一批云端记录合进本地：同 id 就地替换，带 deleted 标记的删掉，新的追加。
  /// 就地替换是为了不打乱列表顺序（先删后加会让改过的心愿跳到末尾）。
  static void _mergeList<E>(
    List<E> local,
    List? raw,
    E Function(Map<String, dynamic>) parse,
    String Function(E) idOf,
    bool Function(E) isDeleted,
  ) {
    for (final j in raw ?? const []) {
      final item = parse(j as Map<String, dynamic>);
      final i = local.indexWhere((x) => idOf(x) == idOf(item));
      if (isDeleted(item)) {
        if (i >= 0) local.removeAt(i);
      } else if (i >= 0) {
        local[i] = item;
      } else {
        local.add(item);
      }
    }
  }

  /// 拉取云端数据。
  /// [full] = true 时全量拉并整体替换本地（登录/切账号时用）；
  /// 否则只拉上次拉取之后变过的记录，合并进本地——启动一次的数据库读取量
  /// 从「这个账号的全部记录」降到「上次之后改过的几条」，额度差一个数量级。
  Future<void> _pullFromCloud({bool full = false}) async {
    try {
      final since = full ? 0 : await Session.lastPull(account);
      final res = await SyncApi.pull(since);
      final ws = (res['wishes'] as List?) ?? [];
      final ts = (res['tasks'] as List?) ?? [];
      final ls = (res['letters'] as List?) ?? [];
      _pushTimer?.cancel();
      _dirtyWishes.clear();
      _dirtyTasks.clear();
      _dirtyLetters.clear();
      if (since == 0) {
        wishes.clear();
        tasks.clear();
        letters.clear();
      }
      _mergeList(wishes, ws, Wish.fromJson, (w) => w.id, (w) => w.deleted);
      _mergeList(tasks, ts, Task.fromJson, (t) => t.id, (t) => t.deleted);
      _mergeList(letters, ls, Letter.fromJson, (l) => l.id, (l) => l.deleted);
      // 服务端给的时间戳，下次从这里往后拉；拉失败就不推进，宁可重拉一次也别漏
      final now = (res['now'] as num?)?.toInt();
      if (now != null) await Session.saveLastPull(account, now);
      final profile = res['profile'] as Map<String, dynamic>?;
      if (profile != null) {
        final nick = profile['nickname'] as String?;
        if (nick != null && nick.isNotEmpty) nickname = nick;
        // 云端有头像就用云端的；云端没有但本地有（上次推送悄悄失败了），
        // 保住本地的并补推一次，别让 null 把头像抹掉
        final cloudAvatar = profile['avatarUrl'] as String?;
        if (cloudAvatar != null) {
          avatarUrl = cloudAvatar;
        } else if (avatarUrl != null) {
          unawaited(_pushProfile(avatarUrl: avatarUrl));
        }
        _saveAvatarLocal();
        gender = profile['gender'] as String? ?? gender;
        final bd = profile['birthday'] as String?;
        if (bd != null && bd.isNotEmpty) birthday = _dayParse(bd);
        accountCreatedAt = _fromMs(profile['createdAt'] as num?);
        final cloudAchv = ((profile['achievements'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        final localOnly =
            achvUnlocked.keys.any((k) => !cloudAchv.containsKey(k));
        achvUnlocked = {...achvUnlocked, ...cloudAchv};
        _migrateAchvKeys(); // 云端可能还是老的中文名 key
        _saveAchvLocal();
        if (localOnly) {
          unawaited(_pushProfile(achievements: achvUnlocked));
        }
        // 景区打卡同成就：本地和云端取并集，同一处保留更早的首次时间
        final cloudCk = ((profile['checkins'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        final ckLocalOnly = checkins.entries.any(
          (e) => (cloudCk[e.key] ?? (e.value + 1)) > e.value,
        );
        cloudCk.forEach((k, v) {
          final cur = checkins[k];
          checkins[k] = cur == null || v < cur ? v : cur;
        });
        _saveCheckinsLocal();
        if (ckLocalOnly) {
          unawaited(_pushProfile(checkins: checkins));
        }
        // 排行榜计数平时只搭改动推送的顺风车；老账号没有新改动就永远上不了榜。
        // 所以拉取后对一次账：云端计数和本地算的不一致，就单独补推一次。
        final counters = rankCounters();
        final stale = counters.entries.any(
          (e) => ((profile[e.key] as num?)?.toInt() ?? 0) != e.value,
        );
        if (stale) {
          unawaited(SyncApi.push(profile: counters));
        }
      }
      _saveCache();
    } catch (e) {
      // 拉取失败：保留当前本地数据（可能来自本地缓存），不阻断登录/启动流程
      if (e is ApiException && e.code == 401) unawaited(_handleUnauthorized());
    }
  }

  /// 后台同步撞见 401（token 失效/过期）时置一次位，UI 层弹一次重新登录就复位，
  /// 不然本地数据还在、看着像正常登录，其实早就同步不动了，用户完全没感知
  bool sessionExpired = false;

  Future<void> _handleUnauthorized() async {
    if (!signedIn) return; // 已经是未登录态，不重复处理
    signedIn = false;
    sessionExpired = true;
    await Session.clear(); // 这个 token 确认废了，别再带着它发请求
    notifyListeners();
  }

  /// 心愿/任务/信件只存内存，重启后全靠这份本地缓存兜底：
  /// 没有它的话，启动时的增量拉取只拉「上次水位之后」的改动，
  /// 云端没新东西就一条都拉不回来，界面只剩默认清单（等于数据丢了）。
  void _saveCache() {
    final acc = account;
    if (!signedIn || acc == null) return;
    final body = jsonEncode({
      'wishes': wishes.map((w) => w.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'letters': letters.map((l) => l.toJson()).toList(),
    });
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setString('sync_cache_$acc', body)));
  }

  /// 启动时装回缓存；装到了返回 true（之后增量拉即可），没装到就得全量拉
  Future<bool> _loadCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('sync_cache_$account');
      if (raw == null) return false;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      wishes
        ..clear()
        ..addAll((m['wishes'] as List).map((e) => Wish.fromJson(e)));
      tasks
        ..clear()
        ..addAll((m['tasks'] as List).map((e) => Task.fromJson(e)));
      letters
        ..clear()
        ..addAll((m['letters'] as List).map((e) => Letter.fromJson(e)));
      return true;
    } catch (_) {
      return false; // 缓存坏了就当没有，走全量拉
    }
  }

  /// 为某个已完成心愿生成分享短码，返回短链路径（如 /s/AB12CD）
  Future<String> shareWish(Wish w) async {
    final res = await ShareApi.create(
      wishId: w.id,
      title: w.title,
      quote: w.quote,
      color: _hex(w.color),
    );
    return (res['path'] as String?) ?? '';
  }

  static const heroes = [
    [Color(0xFF8FB8D0), Color(0xFF4E7A96), Color(0xFF22364A)],
    [Color(0xFFD8B98A), Color(0xFFB98F5E), Color(0xFF7E5C3A)],
    [Color(0xFF9FB8A6), Color(0xFF6E8E7C), Color(0xFF48604F)],
    [Color(0xFFB8A8C4), Color(0xFF8A7A9E), Color(0xFF5C4F70)],
  ];

  List<Wish> get activeWishes => wishes.where((w) => !w.done).toList();
  List<Wish> get doneWishes =>
      wishes.where((w) => w.done).toList()
        ..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));

  Wish? wishOf(Task t) {
    if (t.wishId == null) return null;
    for (final w in wishes) {
      if (w.id == t.wishId) return w;
    }
    return null;
  }

  Color taskColor(Task t) => t.color ?? wishOf(t)?.color ?? T.grey;

  List<Task> tasksOn(DateTime day) =>
      tasks.where((t) => sameDay(t.day, day)).toList();

  List<Task> tasksOfWish(String wishId) =>
      tasks.where((t) => t.wishId == wishId).toList()
        ..sort((a, b) => b.day.compareTo(a.day));

  /// 当天日历标记点颜色：取当天第一个有色任务
  Color? dotOn(DateTime day) {
    final list = tasksOn(day);
    if (list.isEmpty) return null;
    for (final t in list) {
      final c = t.color ?? wishOf(t)?.color;
      if (c != null) return c;
    }
    return T.grey;
  }

  void toggleTask(Task t) {
    t.done = !t.done;
    if (t.done) {
      HapticFeedback.lightImpact();
    }
    _touchTask(t);
    notifyListeners();
  }

  /// 任务字段（标题/日期/描述/配图…）改完之后调用，推送到云端并刷新界面
  void updateTask(Task t) {
    _touchTask(t);
    notifyListeners();
  }

  /// 软删除：本地立即消失，同时把删除标记同步给云端
  void deleteTask(Task t) {
    t.deleted = true;
    _touchTask(t);
    tasks.remove(t);
    notifyListeners();
  }

  Task addTask(
    String title,
    DateTime day, {
    String? wishId,
    Color? color,
    String? desc,
    String? time,
    bool remind = false,
  }) {
    final t = Task(
      id: _newId('t'),
      title: title,
      day: dOnly(day),
      wishId: wishId,
      color: color,
      desc: desc,
      time: time,
      remind: remind,
    );
    tasks.add(t);
    _touchTask(t);
    notifyListeners();
    return t;
  }

  Wish addWish(String title, Color color, {String? desc}) {
    final w = Wish(
      id: _newId('w'),
      title: title,
      color: color,
      createdAt: DateTime.now(),
      desc: desc,
    );
    wishes.add(w);
    _touchWish(w);
    notifyListeners();
    return w;
  }

  /// 心愿字段（标题/描述/颜色）改完之后调用，推送到云端并刷新界面
  void updateWish(Wish w) {
    _touchWish(w);
    notifyListeners();
  }

  /// 软删除心愿：本地立即消失，同时把删除标记同步给云端。
  /// 关联任务保留（wishId 指向的心愿不在了，会当成杂事显示）
  void deleteWish(Wish w) {
    w.deleted = true;
    _touchWish(w);
    wishes.remove(w);
    notifyListeners();
  }

  // ---------- 里程碑 ----------
  WishStep addStep(Wish w, String title) {
    final s = WishStep(id: _newId('s'), title: title);
    w.steps.add(s);
    _touchWish(w);
    notifyListeners();
    return s;
  }

  /// 一次性写入一组里程碑（用预置模板拆解时用）
  void addSteps(Wish w, Iterable<String> titles) {
    for (final t in titles) {
      w.steps.add(WishStep(id: _newId('s'), title: t));
    }
    _touchWish(w);
    notifyListeners();
  }

  void toggleStep(Wish w, WishStep s) {
    s.done = !s.done;
    s.doneAt = s.done ? DateTime.now() : null;
    if (s.done) HapticFeedback.lightImpact();
    _touchWish(w);
    notifyListeners();
  }

  void renameStep(Wish w, WishStep s, String title) {
    s.title = title;
    _touchWish(w);
    notifyListeners();
  }

  void deleteStep(Wish w, WishStep s) {
    w.steps.remove(s);
    _touchWish(w);
    notifyListeners();
  }

  // ---------- 过程笔记 ----------
  WishNote addNote(Wish w, String text) {
    final n = WishNote(id: _newId('n'), text: text, at: DateTime.now());
    w.notes.insert(0, n); // 新的在前
    _touchWish(w);
    notifyListeners();
    return n;
  }

  void deleteNote(Wish w, WishNote n) {
    w.notes.remove(n);
    _touchWish(w);
    notifyListeners();
  }

  // ---------- 目标日期 ----------
  void setWishTarget(Wish w, DateTime? day) {
    w.targetAt = day == null ? null : dOnly(day);
    _touchWish(w);
    notifyListeners();
  }

  // ---------- 照片 ----------
  /// 正在上传照片的心愿 id（详情页据此显示"上传中"占位格）
  String? photoUploadingWishId;
  void setPhotoUploading(String? wishId) {
    photoUploadingWishId = wishId;
    notifyListeners();
  }

  void addWishPhoto(Wish w, String url) {
    w.photos.add(url);
    _touchWish(w);
    notifyListeners();
  }

  void removeWishPhoto(Wish w, String url) {
    w.photos.remove(url);
    _touchWish(w);
    notifyListeners();
  }

  /// 把某张照片挪到最后 = 设为封面（展示处都取 photos.last）
  void setCoverPhoto(Wish w, String url) {
    if (!w.photos.remove(url)) return;
    w.photos.add(url);
    _touchWish(w);
    notifyListeners();
  }

  /// 批量软删除：整批打一次删除标记合并推云端，只刷一次界面
  void deleteWishes(Iterable<Wish> list) {
    final batch = list.toList();
    if (batch.isEmpty) return;
    for (final w in batch) {
      w.deleted = true;
      _touchWish(w);
      wishes.remove(w);
    }
    notifyListeners();
  }

  /// 播下前 50 条「人生必做清单」。
  /// - 未登录时：纯本地预览，_touchWish 会提前 return，不进脏队列、不上云；
  /// - 注册新账号后：此时已是登录态，每条都会进脏队列并同步到云端，成为真实数据。
  void _seedLifeGoals() {
    final rand = Random();
    final n = lifeGoals.length < 50 ? lifeGoals.length : 50;
    for (var i = 0; i < n; i++) {
      addWish(lifeGoals[i], T.wishPalette[rand.nextInt(T.wishPalette.length)]);
    }
  }

  void completeWish(
    Wish w, {
    required String quote,
    String? location,
    required int heroIndex,
  }) {
    w.done = true;
    w.doneAt = DateTime.now();
    w.quote = quote.isEmpty ? '这一天，终于到了。' : quote;
    w.location = (location == null || location.isEmpty) ? null : location;
    w.heroIndex = heroIndex % heroes.length;
    HapticFeedback.mediumImpact();
    _touchWish(w);
    notifyListeners();
  }

  /// 把已完成的心愿变回进行中：清掉完成时间/地点（地图上的点会一起熄灭），
  /// 当时写的那句话保留在 quote 里不丢
  void uncompleteWish(Wish w) {
    w.done = false;
    w.doneAt = null;
    w.location = null;
    _touchWish(w);
    notifyListeners();
  }

  int doneNumberOf(Wish w) {
    final list = wishes.where((x) => x.done).toList()
      ..sort((a, b) => a.doneAt!.compareTo(b.doneAt!));
    final i = list.indexOf(w);
    return i < 0 ? list.length : i + 1;
  }

  /// 写一封时光胶囊信，到 openAt 那天才能开启
  Letter addLetter(String title, String content, DateTime openAt) {
    final l = Letter(
      id: _newId('l'),
      title: title,
      content: content,
      openAt: openAt,
    );
    letters.add(l);
    _touchLetter(l);
    notifyListeners();
    return l;
  }

  /// 是否已到开启日期
  bool isLetterOpen(Letter l) => !DateTime.now().isBefore(l.openAt);

  // 个人资料
  String nickname = '松之';
  String? avatarUrl; // 头像照片（云存储稳定链接）；null = 默认头像
  String? gender; // '男' / '女'；null = 没填
  DateTime? birthday; // 生日；年龄按它算，不用每年手动改

  /// 按生日算的周岁；没填生日就是 null
  int? get age {
    final b = birthday;
    if (b == null) return null;
    final now = DateTime.now();
    var a = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) a--;
    return a < 0 ? 0 : a;
  }

  DateTime? accountCreatedAt; // 账号创建时间（后端 profile.createdAt），未登录时为 null
  void updateProfile({String? nickname, String? gender, DateTime? birthday}) {
    if (nickname != null && nickname.isNotEmpty) this.nickname = nickname;
    if (gender != null) this.gender = gender;
    if (birthday != null) this.birthday = birthday;
    notifyListeners();
    if (signedIn) {
      unawaited(_pushProfile(
        nickname: nickname,
        gender: gender,
        birthday: birthday == null ? null : _dayStr(birthday),
      ));
    }
  }

  // ---------- 成就（勋章）----------
  /// 成就名 → 点亮时间(ms)。拿到即永久：本机存一份，登录后与云端合并双向同步
  /// 点亮记录：key 是成就的 slug（不是显示名）。
  /// 早期版本用中文显示名当 key，改个文案就会让所有人的勋章集体熄灭；
  /// 读进来时统一迁移成 slug，见 [_migrateAchvKeys]。
  Map<String, int> achvUnlocked = {};
  static const _achvKey = 'achv_unlocked';

  @visibleForTesting
  void migrateAchvKeysForTest() => _migrateAchvKeys();

  /// 老数据兼容：把中文名 key 换成 slug。两边都有时保留更早的那次点亮时间。
  void _migrateAchvKeys() {
    if (achvUnlocked.isEmpty) return;
    final bySlug = <String, int>{};
    var changed = false;
    achvUnlocked.forEach((k, v) {
      final slug = achvSlugByName[k];
      if (slug == null) {
        bySlug[k] = bySlug.containsKey(k) ? (bySlug[k]! < v ? bySlug[k]! : v) : v;
      } else {
        changed = true;
        bySlug[slug] =
            bySlug.containsKey(slug) && bySlug[slug]! < v ? bySlug[slug]! : v;
      }
    });
    if (changed) {
      achvUnlocked = bySlug;
      _saveAchvLocal();
      if (signedIn) unawaited(_pushProfile(achievements: achvUnlocked));
    }
  }

  Future<void> _loadAchvLocal() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_achvKey);
      if (raw != null) {
        achvUnlocked = (jsonDecode(raw) as Map)
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        _migrateAchvKeys();
      }
      final rawCk = p.getString(_checkinKey);
      if (rawCk != null) {
        checkins = (jsonDecode(rawCk) as Map)
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    } catch (_) {}
  }

  void _saveAchvLocal() {
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setString(_achvKey, jsonEncode(achvUnlocked))));
  }

  // ---------- 景区打卡 ----------
  /// 景区名 → 首次打卡时间(ms)。和成就同一套玩法：本机存一份，登录后与云端并集同步
  Map<String, int> checkins = {};
  static const _checkinKey = 'spot_checkins';

  void _saveCheckinsLocal() {
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setString(_checkinKey, jsonEncode(checkins))));
  }

  /// 定位打卡点亮一个景区（幂等，保留首次时间）
  void checkIn(String name) {
    if (checkins.containsKey(name)) return;
    checkins[name] = DateTime.now().millisecondsSinceEpoch;
    _saveCheckinsLocal();
    notifyListeners();
    if (signedIn) {
      // 打卡和足迹计数一起推，排行榜立刻是新的，不用等下次同步
      unawaited(SyncApi.push(
        profile: {...rankCounters(), 'checkins': checkins},
      ));
    }
  }

  /// 点亮一批成就（幂等）：记本机 + 推云端。传的是 slug，不是显示名。
  void unlockAchvs(Iterable<String> slugs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final n in slugs) {
      if (!achvUnlocked.containsKey(n)) {
        achvUnlocked[n] = now;
        changed = true;
      }
    }
    if (!changed) return;
    _saveAchvLocal();
    if (signedIn) {
      unawaited(_pushProfile(achievements: achvUnlocked));
    }
    notifyListeners();
  }

  /// 上传好的照片设为头像
  void setAvatarPhoto(String url) {
    avatarUrl = url;
    _saveAvatarLocal();
    notifyListeners();
    if (signedIn) {
      unawaited(_pushProfile(avatarUrl: url));
    }
  }

  /// 头像链接本地也存一份：不然每次启动都赌云端拉取成功，
  /// 云函数冷启动慢或网络一抖，头像就"消失"了（心愿有缓存兜底，头像也得有）
  static const _avatarKey = 'avatar_url';
  void _saveAvatarLocal() {
    unawaited(SharedPreferences.getInstance().then(
      (p) => avatarUrl == null
          ? p.remove(_avatarKey)
          : p.setString(_avatarKey, avatarUrl!),
    ));
  }

  Future<void> _pushProfile({
    String? nickname,
    String? avatarUrl,
    Map<String, int>? achievements,
    Map<String, int>? checkins,
    String? gender,
    String? birthday,
  }) async {
    try {
      await AuthApi.updateProfile(
        nickname: nickname,
        avatarUrl: avatarUrl,
        achievements: achievements,
        checkins: checkins,
        gender: gender,
        birthday: birthday,
      );
    } catch (_) {
      // 静默失败：资料改动仍留在本地，下次改资料时会一并再推
    }
  }

  // 登录态（接后端）
  bool signedIn = false;
  String? account;

  /// 启动时装回本地会话；已登录则用云端数据整体替换本地演示数据
  Future<void> initSession() async {
    await _loadAchvLocal();
    await Session.load();
    signedIn = Session.isLoggedIn;
    account = await Session.account();
    final nick = await Session.nick();
    if (nick != null && nick.isNotEmpty) nickname = nick;
    if (signedIn) {
      // 先装本地存的头像，云端拉取成功后会覆盖；拉取失败也不至于头像消失
      avatarUrl = (await SharedPreferences.getInstance()).getString(_avatarKey);
    }
    if (signedIn) {
      // 先装本地缓存再增量拉；没缓存（新装/缓存坏了）就必须全量拉，
      // 不然增量什么都拉不到，界面只剩默认清单
      final cached = await _loadCache();
      await _pullFromCloud(full: !cached);
    }
    notifyListeners();
  }

  /// 账号密码登录 / 注册；成功后置登录态、存 token，并拉取云端数据。
  /// 新注册的账号会自动生成 50 条人生清单并推送上云——它们从第一秒起就是这个账号
  /// 在云端的真实数据，不是本地假数据（登录老账号不会重复播种）。
  Future<void> loginOrRegister(
    String account,
    String password, {
    bool register = false,
  }) async {
    final res = register
        ? await AuthApi.register(account, password)
        : await AuthApi.login(account, password);
    final token = res['token'] as String?;
    if (token == null) throw ApiException(0, '登录失败');
    final profile = res['profile'] as Map<String, dynamic>?;
    final nick = profile?['nickname'] as String?;
    await Session.save(token: token, account: account, nick: nick);
    this.account = account;
    if (nick != null && nick.isNotEmpty) nickname = nick;
    signedIn = true;
    await _pullFromCloud(full: true); // 可能是换账号，必须整体替换
    if (register && wishes.isEmpty) _seedLifeGoals(); // 会随防抖推送上云
    notifyListeners();
  }

  /// 退出登录：清会话、清云端数据，回到本地预览
  Future<void> logout() async {
    await Session.saveLastPull(account, 0); // 本地数据要清空，下次必须全量重拉
    final acc = account;
    if (acc != null) {
      unawaited(SharedPreferences.getInstance()
          .then((p) => p.remove('sync_cache_$acc')));
    }
    await Session.clear();
    signedIn = false;
    account = null;
    accountCreatedAt = null;
    avatarUrl = null;
    _saveAvatarLocal(); // 清掉本地存的头像
    gender = null;
    birthday = null;
    achvUnlocked = {};
    _saveAchvLocal();
    checkins = {};
    _saveCheckinsLocal();
    _pushTimer?.cancel();
    _dirtyWishes.clear();
    _dirtyTasks.clear();
    _dirtyLetters.clear();
    wishes.clear();
    tasks.clear();
    letters.clear();
    _seedLifeGoals(); // 退出后回到未登录预览
    notifyListeners();
  }

  /// 注销账号（远端软删除 + 本地清会话）
  Future<void> deleteAccountRemote() async {
    try {
      await AuthApi.deleteAccount();
    } catch (_) {}
    await logout();
  }

  // 我的页统计：全部由真实任务/账号数据算出，不再是假数字
  int get totalDays => accountCreatedAt == null
      ? 0
      : dOnly(DateTime.now()).difference(dOnly(accountCreatedAt!)).inDays + 1;

  /// 连续天数：从今天往前数，每天至少有一次「记录」，中断即止。
  /// 记录不只完成任务——实现心愿、记笔记、写信、景区打卡都算；
  /// 今天还没动只从昨天起算，别把攒到昨天的连续直接清零。
  int get streakDays {
    final days = <DateTime>{
      for (final t in tasks.where((t) => t.done)) dOnly(t.day),
      for (final w in wishes) ...[
        dOnly(w.createdAt),
        if (w.doneAt != null) dOnly(w.doneAt!),
        for (final n in w.notes) dOnly(n.at),
      ],
      for (final l in letters) dOnly(l.createdAt),
      for (final ms in checkins.values)
        dOnly(DateTime.fromMillisecondsSinceEpoch(ms)),
    };
    var streak = 0;
    var day = dOnly(DateTime.now());
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    while (days.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 今年有完成任务的天数
  int get pushedDaysThisYear {
    final year = DateTime.now().year;
    return tasks
        .where((t) => t.done && t.day.year == year)
        .map((t) => dOnly(t.day))
        .toSet()
        .length;
  }

  int get doneTaskCount => tasks.where((t) => t.done).length;
}
