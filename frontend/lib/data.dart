import 'dart:async';
import 'dart:convert' show jsonEncode, utf8;
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'api/api.dart';
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
DateTime _fromMs(num? ms) =>
    ms == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(ms.toInt());

DateTime dOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String md(DateTime d) => '${d.month}月${d.day}日';
String ymDots(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}';
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
    this.deleted = false,
  }) : updatedAt = updatedAt ?? createdAt;
  final String id;
  String title;
  Color color;
  bool done;
  DateTime createdAt;
  DateTime updatedAt; // 供云端 LWW 冲突判断
  DateTime? doneAt;
  String? quote;
  String? location;
  int? heroIndex; // 凭证照片渐变的下标（演示用）
  String? desc; // 描述
  bool deleted;

  List<Color>? get hero =>
      heroIndex == null ? null : AppData.heroes[heroIndex! % AppData.heroes.length];

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
        deleted: j['deleted'] as bool? ?? false,
      );
}

class Task {
  Task({
    required this.id,
    required this.title,
    required this.day,
    this.wishId,
    this.done = false,
    this.time,
    this.color,
    this.desc,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();
  final String id;
  String title;
  DateTime day;
  String? wishId; // null = 杂事
  bool done;
  String? time;
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
  })  : createdAt = createdAt ?? DateTime.now(),
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
    _fillLifeGoals();
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
      unawaited(_flushPush());
    }
  }

  final wishes = <Wish>[];
  final tasks = <Task>[];
  final letters = <Letter>[];
  int _idSeq = 0;
  String _newId(String prefix) {
    _idSeq++;
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_idSeq.toRadixString(36)}';
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
      unawaited(_flushPush());
    });
  }

  // 云函数网关单次请求体上限约 100KB，超量的批量改动（比如一次性导入/改一堆任务）
  // 得分批推送，不然整批直接被网关 413 拒掉、还静默吞掉
  static const _pushChunkBudget = 80 * 1024;

  List<_PushChunk> _buildPushChunks(List<Wish> ws, List<Task> ts, List<Letter> ls) {
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
    if (_dirtyWishes.isEmpty && _dirtyTasks.isEmpty && _dirtyLetters.isEmpty) return;
    final chunks = _buildPushChunks(
        _dirtyWishes.toList(), _dirtyTasks.toList(), _dirtyLetters.toList());
    _dirtyWishes.clear();
    _dirtyTasks.clear();
    _dirtyLetters.clear();
    for (var i = 0; i < chunks.length; i++) {
      final c = chunks[i];
      try {
        await SyncApi.push(
          wishes: c.wishes.isEmpty ? null : c.wishes.map((w) => w.toJson()).toList(),
          tasks: c.tasks.isEmpty ? null : c.tasks.map((t) => t.toJson()).toList(),
          letters: c.letters.isEmpty ? null : c.letters.map((l) => l.toJson()).toList(),
        );
      } catch (_) {
        // 静默失败：把这批和还没发的都放回去，下次该条目再变更（或下次启动）时重推
        for (var j = i; j < chunks.length; j++) {
          _dirtyWishes.addAll(chunks[j].wishes);
          _dirtyTasks.addAll(chunks[j].tasks);
          _dirtyLetters.addAll(chunks[j].letters);
        }
        return;
      }
    }
  }

  /// 用云端数据整体替换本地（登录成功 / 已登录状态下启动时调用）
  Future<void> _pullFromCloud() async {
    try {
      final res = await SyncApi.pull(0);
      final ws = (res['wishes'] as List?) ?? [];
      final ts = (res['tasks'] as List?) ?? [];
      final ls = (res['letters'] as List?) ?? [];
      _pushTimer?.cancel();
      _dirtyWishes.clear();
      _dirtyTasks.clear();
      _dirtyLetters.clear();
      wishes
        ..clear()
        ..addAll(ws
            .map((j) => Wish.fromJson(j as Map<String, dynamic>))
            .where((w) => !w.deleted));
      tasks
        ..clear()
        ..addAll(ts
            .map((j) => Task.fromJson(j as Map<String, dynamic>))
            .where((t) => !t.deleted));
      letters
        ..clear()
        ..addAll(ls
            .map((j) => Letter.fromJson(j as Map<String, dynamic>))
            .where((l) => !l.deleted));
      final profile = res['profile'] as Map<String, dynamic>?;
      if (profile != null) {
        final nick = profile['nickname'] as String?;
        if (nick != null && nick.isNotEmpty) nickname = nick;
        avatarEmoji = profile['avatarEmoji'] as String?;
        accountCreatedAt = _fromMs(profile['createdAt'] as num?);
      }
      // 云端心愿为空就兜底填入默认清单，不管是新注册还是老账号空着——不允许出现空列表
      if (wishes.isEmpty) _fillLifeGoals();
    } catch (_) {
      // 拉取失败：保留当前本地数据，不阻断登录/启动流程
    }
  }

  /// 为某个已完成心愿生成分享短码，返回短链路径（如 /s/AB12CD）
  Future<String> shareWish(Wish w) async {
    final res = await ShareApi.create(
        wishId: w.id, title: w.title, quote: w.quote, color: _hex(w.color));
    return (res['path'] as String?) ?? '';
  }

  static const heroes = [
    [Color(0xFF8FB8D0), Color(0xFF4E7A96), Color(0xFF22364A)],
    [Color(0xFFD8B98A), Color(0xFFB98F5E), Color(0xFF7E5C3A)],
    [Color(0xFF9FB8A6), Color(0xFF6E8E7C), Color(0xFF48604F)],
    [Color(0xFFB8A8C4), Color(0xFF8A7A9E), Color(0xFF5C4F70)],
  ];

  List<Wish> get activeWishes => wishes.where((w) => !w.done).toList();
  List<Wish> get doneWishes => wishes.where((w) => w.done).toList()
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

  Task addTask(String title, DateTime day,
      {String? wishId, Color? color, String? desc}) {
    final t = Task(
      id: _newId('t'),
      title: title,
      day: dOnly(day),
      wishId: wishId,
      color: color,
      desc: desc,
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
        desc: desc);
    wishes.add(w);
    _touchWish(w);
    notifyListeners();
    return w;
  }

  /// 填入前 50 条「人生必做清单」：未登录时作为本地预览（不会同步，登录后被云端数据整体替换）；
  /// 新注册账号在云端为空时也用它兜底，此时会正常同步上云
  void _fillLifeGoals() {
    final rand = Random();
    final n = lifeGoals.length < 50 ? lifeGoals.length : 50;
    for (var i = 0; i < n; i++) {
      addWish(lifeGoals[i], T.wishPalette[rand.nextInt(T.wishPalette.length)]);
    }
  }

  void completeWish(Wish w,
      {required String quote, String? location, required int heroIndex}) {
    w.done = true;
    w.doneAt = DateTime.now();
    w.quote = quote.isEmpty ? '这一天，终于到了。' : quote;
    w.location = (location == null || location.isEmpty) ? null : location;
    w.heroIndex = heroIndex % heroes.length;
    HapticFeedback.mediumImpact();
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
        id: _newId('l'), title: title, content: content, openAt: openAt);
    letters.add(l);
    _touchLetter(l);
    notifyListeners();
    return l;
  }

  /// 是否已到开启日期
  bool isLetterOpen(Letter l) => !DateTime.now().isBefore(l.openAt);

  // 个人资料
  String nickname = '松之';
  String? avatarEmoji; // null = 用昵称首字
  DateTime? accountCreatedAt; // 账号创建时间（后端 profile.createdAt），未登录时为 null
  void updateProfile({String? nickname, String? avatarEmoji, bool clearEmoji = false}) {
    if (nickname != null && nickname.isNotEmpty) this.nickname = nickname;
    if (clearEmoji) {
      this.avatarEmoji = null;
    } else if (avatarEmoji != null) {
      this.avatarEmoji = avatarEmoji;
    }
    notifyListeners();
    if (signedIn) {
      unawaited(_pushProfile(
          nickname: nickname,
          avatarEmoji: clearEmoji ? null : avatarEmoji,
          clearEmoji: clearEmoji));
    }
  }

  Future<void> _pushProfile(
      {String? nickname, String? avatarEmoji, bool clearEmoji = false}) async {
    try {
      await AuthApi.updateProfile(
          nickname: nickname, avatarEmoji: avatarEmoji, clearEmoji: clearEmoji);
    } catch (_) {
      // 静默失败：资料改动仍留在本地，下次改资料时会一并再推
    }
  }

  // 登录态（接后端）
  bool signedIn = false;
  String? email;

  /// 启动时装回本地会话；已登录则用云端数据整体替换本地演示数据
  Future<void> initSession() async {
    await Session.load();
    signedIn = Session.isLoggedIn;
    email = await Session.email();
    final nick = await Session.nick();
    if (nick != null && nick.isNotEmpty) nickname = nick;
    if (signedIn) await _pullFromCloud();
    notifyListeners();
  }

  /// 邮箱登录 / 注册；成功后置登录态、存 token，并拉取云端数据（云端心愿为空会自动导入 50 个人生清单兜底）
  /// （注册需先 AuthApi.sendCode 拿到验证码）
  Future<void> loginOrRegister(String email, String password,
      {bool register = false, String? code}) async {
    final res = register
        ? await AuthApi.register(email, password, code ?? '')
        : await AuthApi.login(email, password);
    final token = res['token'] as String?;
    if (token == null) throw ApiException(0, '登录失败');
    final profile = res['profile'] as Map<String, dynamic>?;
    final nick = profile?['nickname'] as String?;
    await Session.save(token: token, email: email, nick: nick);
    this.email = email;
    if (nick != null && nick.isNotEmpty) nickname = nick;
    signedIn = true;
    await _pullFromCloud(); // 云端为空会在 _pullFromCloud 里自动兜底填默认清单
    notifyListeners();
  }

  /// 退出登录：清会话、清云端数据，回到本地预览
  Future<void> logout() async {
    await Session.clear();
    signedIn = false;
    email = null;
    accountCreatedAt = null;
    _pushTimer?.cancel();
    _dirtyWishes.clear();
    _dirtyTasks.clear();
    _dirtyLetters.clear();
    wishes.clear();
    tasks.clear();
    letters.clear();
    _fillLifeGoals();
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

  /// 连续打卡天数：从今天往前数，每天至少完成一个任务，中断即止
  int get streakDays {
    final doneDays = tasks.where((t) => t.done).map((t) => dOnly(t.day)).toSet();
    var streak = 0;
    var day = dOnly(DateTime.now());
    while (doneDays.contains(day)) {
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

/// 点亮地图城市（演示坐标：0~1 分数位置）
class MapCity {
  const MapCity(this.name, this.fx, this.fy, this.lit);
  final String name;
  final double fx, fy;
  final bool lit;
}

const mapCities = [
  MapCity('大理', .29, .25, true),
  MapCity('上海', .57, .41, true),
  MapCity('涛岛', .39, .65, true),
  MapCity('成都', .65, .79, true),
  MapCity('东京', .80, .30, false),
  MapCity('冰岛', .14, .12, false),
  MapCity('冲绳', .76, .58, false),
];
