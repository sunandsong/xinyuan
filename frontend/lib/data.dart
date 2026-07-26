import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'api/api.dart';
import 'session.dart';
import 'theme.dart';

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
    this.done = false,
    this.doneAt,
    this.quote,
    this.location,
    this.hero,
    this.desc,
  });
  final int id;
  String title;
  Color color;
  bool done;
  DateTime createdAt;
  DateTime? doneAt;
  String? quote;
  String? location;
  List<Color>? hero; // 凭证照片（演示用渐变）
  String? desc; // 描述
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
  });
  final int id;
  String title;
  DateTime day;
  int? wishId; // null = 杂事
  bool done;
  String? time;
  Color? color; // 任务自身颜色
  String? desc; // 描述
}

/// 全局死数据（内存态，可交互，不持久化）
class AppData extends ChangeNotifier {
  AppData._() {
    _seed();
  }
  static final AppData I = AppData._();

  final wishes = <Wish>[];
  final tasks = <Task>[];
  int _nid = 1;
  int nextId() => _nid++;

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

  List<Task> tasksOfWish(int wishId) =>
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
    notifyListeners();
  }

  Task addTask(String title, DateTime day,
      {int? wishId, Color? color, String? desc}) {
    final t = Task(
      id: nextId(),
      title: title,
      day: dOnly(day),
      wishId: wishId,
      color: color,
      desc: desc,
    );
    tasks.add(t);
    notifyListeners();
    return t;
  }

  Wish addWish(String title, Color color, {String? desc}) {
    final w = Wish(
        id: nextId(),
        title: title,
        color: color,
        createdAt: DateTime.now(),
        desc: desc);
    wishes.add(w);
    notifyListeners();
    return w;
  }

  void completeWish(Wish w,
      {required String quote, String? location, required int heroIndex}) {
    w.done = true;
    w.doneAt = DateTime.now();
    w.quote = quote.isEmpty ? '这一天，终于到了。' : quote;
    w.location = (location == null || location.isEmpty) ? null : location;
    w.hero = heroes[heroIndex % heroes.length];
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  int doneNumberOf(Wish w) {
    final list = wishes.where((x) => x.done).toList()
      ..sort((a, b) => a.doneAt!.compareTo(b.doneAt!));
    final i = list.indexOf(w);
    return i < 0 ? list.length : i + 1;
  }

  // 个人资料
  String nickname = '松之';
  String? avatarEmoji; // null = 用昵称首字
  void updateProfile({String? nickname, String? avatarEmoji, bool clearEmoji = false}) {
    if (nickname != null && nickname.isNotEmpty) this.nickname = nickname;
    if (clearEmoji) {
      this.avatarEmoji = null;
    } else if (avatarEmoji != null) {
      this.avatarEmoji = avatarEmoji;
    }
    notifyListeners();
  }

  // 登录态（接后端）
  bool signedIn = false;
  String? email;

  /// 启动时装回本地会话
  Future<void> initSession() async {
    await Session.load();
    signedIn = Session.isLoggedIn;
    email = await Session.email();
    final nick = await Session.nick();
    if (nick != null && nick.isNotEmpty) nickname = nick;
    notifyListeners();
  }

  /// 邮箱登录 / 注册；成功后置登录态并存 token
  Future<void> loginOrRegister(String email, String password,
      {bool register = false}) async {
    final res = register
        ? await AuthApi.register(email, password)
        : await AuthApi.login(email, password);
    final token = res['token'] as String?;
    if (token == null) throw ApiException(0, '登录失败');
    final profile = res['profile'] as Map<String, dynamic>?;
    final nick = profile?['nickname'] as String?;
    await Session.save(token: token, email: email, nick: nick);
    this.email = email;
    if (nick != null && nick.isNotEmpty) nickname = nick;
    signedIn = true;
    notifyListeners();
    // TODO(下一步)：登录后 pullFromCloud() 拉取云端心愿
  }

  Future<void> logout() async {
    await Session.clear();
    signedIn = false;
    email = null;
    notifyListeners();
  }

  /// 注销账号（远端软删除 + 本地清会话）
  Future<void> deleteAccountRemote() async {
    try {
      await AuthApi.deleteAccount();
    } catch (_) {}
    await logout();
  }

  // 我的页统计（演示口径）
  int get streakDays => 128;
  int get totalDays => 1281;
  int get pushedDaysThisYear => 84;
  int get doneTaskCount => tasks.where((t) => t.done).length + 211;

  void _seed() {
    final today = dOnly(DateTime.now());
    Wish aw(String title, int c, int yy, int mm) {
      final w = Wish(
          id: nextId(),
          title: title,
          color: T.wishPalette[c],
          createdAt: DateTime(yy, mm, 1));
      wishes.add(w);
      return w;
    }

    Wish dw(String title, int heroIdx, String quote, DateTime doneAt,
        String? loc, int yy, int mm) {
      final w = Wish(
        id: nextId(),
        title: title,
        color: T.wishPalette[(heroIdx + 1) % T.wishPalette.length],
        createdAt: DateTime(yy, mm, 1),
        done: true,
        doneAt: doneAt,
        quote: quote,
        location: loc,
        hero: heroes[heroIdx % heroes.length],
      );
      wishes.add(w);
      return w;
    }

    // 进行中
    final dive = aw('学会自由潜水', 0, 2023, 4);
    final ice = aw('去冰岛看极光', 1, 2024, 1);
    final fam = aw('陪爸妈过 30 个周末', 2, 2023, 10);
    aw('出版一本书', 3, 2025, 2);
    aw('在海边住一年', 4, 2024, 6);
    aw('学会弹一首完整的吉他曲', 0, 2025, 5);

    // 已完成（6 颗金果）
    dw('完成一次全程马拉松', 0, '最后两公里在哭', DateTime(2025, 11, 2), '上海',
        2023, 2);
    dw('学会做家乡菜', 1, '妈说火候还差点', DateTime(2024, 6, 18), '成都', 2023,
        11);
    dw('独自去一次远方', 2, '一个人也没那么难', DateTime(2023, 9, 30), '大理',
        2023, 3);
    dw('学会游泳', 3, '终于敢下深水区', DateTime(2023, 5, 11), '涛岛', 2022, 12);
    dw('读完 100 本书', 1, '第 100 本是《活着》', DateTime(2024, 12, 31), null,
        2022, 6);
    dw('攒下第一个十万', 2, '原来我也可以', DateTime(2025, 6, 1), null, 2023, 1);

    // 任务：以今天为锚点铺开
    void tk(int offset, String title, Wish? w,
        {bool done = false, String? time}) {
      tasks.add(Task(
        id: nextId(),
        title: title,
        day: today.add(Duration(days: offset)),
        wishId: w?.id,
        done: done,
        time: time,
      ));
    }

    // 今天
    tk(0, '查 OW 考证机构', dive, time: '09:00');
    tk(0, '存 2000 到旅行账户', ice, time: '12:30');
    tk(0, '给妈打个电话', fam, time: '20:00');
    tk(0, '洗衣服', null, done: true);
    tk(0, '取快递', null, done: true);
    // 未来
    tk(1, '预约耳压体检', dive, time: '10:00');
    tk(2, '试潜体验课', dive, time: '14:00');
    tk(5, '订民宿', ice);
    tk(8, '回家吃饭', fam, time: '18:30');
    tk(11, '练憋气', dive);
    // 过去
    tk(-2, '存 2000 到旅行账户', ice, done: true);
    tk(-3, '做饭', null, done: true);
    tk(-5, '练憋气', dive, done: true);
    tk(-8, '回家吃饭', fam, done: true);
    tk(-10, '查机票', ice, done: true);
    tk(-12, '交房租', null, done: true);
    tk(-15, '做攻略', ice, done: true);
    tk(-15, '洗衣服', null, done: true);
    tk(-18, '给妈打个电话', fam, done: true);
    tk(-21, '陪妈买菜', fam, done: true);
    tk(-24, '大扫除', null, done: true);
  }
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
