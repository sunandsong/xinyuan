import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data.dart';
import '../notification_scheduler.dart';
import '../theme.dart';
import '../ui.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _loading = true;
  bool _enabled = true;
  bool _tasks = true;
  bool _wishes = true;
  bool _letters = true;
  bool _dormant = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _enabled = p.getBool('notif_enabled') ?? true;
      _tasks = p.getBool('notif_tasks') ?? true;
      _wishes = p.getBool('notif_wishes') ?? true;
      _letters = p.getBool('notif_letters') ?? true;
      _dormant = p.getBool('notif_dormant') ?? true;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
    await NotificationScheduler.I.rescheduleAll(
      tasks: AppData.I.tasks,
      wishes: AppData.I.wishes,
      letters: AppData.I.letters,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.bg,
        elevation: 0,
        title: const Text('通知提醒'),
      ),
      body: LayoutBuilder(
        builder: (context, cons) {
          // 内容拉满两侧，平板上比手机宽——字号跟着实际宽度按比例放大，
          // 不然标题和开关之间空一大截
          final s = cardContentScale(context, cons.maxWidth);
          Widget row({
            required String title,
            required bool value,
            required ValueChanged<bool>? onChanged,
          }) => SwitchListTile(
            title: Text(title, style: TextStyle(fontSize: 16 * s)),
            contentPadding: EdgeInsets.symmetric(vertical: 4 * s),
            value: value,
            onChanged: onChanged,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              row(
                title: '接收通知',
                value: _enabled,
                onChanged: (v) {
                  setState(() => _enabled = v);
                  _set('notif_enabled', v);
                },
              ),
              const Divider(),
              row(
                title: '任务到期提醒',
                value: _tasks,
                onChanged: _enabled
                    ? (v) {
                        setState(() => _tasks = v);
                        _set('notif_tasks', v);
                      }
                    : null,
              ),
              row(
                title: '心愿期限提醒',
                value: _wishes,
                onChanged: _enabled
                    ? (v) {
                        setState(() => _wishes = v);
                        _set('notif_wishes', v);
                      }
                    : null,
              ),
              row(
                title: '时光胶囊开启提醒',
                value: _letters,
                onChanged: _enabled
                    ? (v) {
                        setState(() => _letters = v);
                        _set('notif_letters', v);
                      }
                    : null,
              ),
              row(
                title: '好久没来提醒',
                value: _dormant,
                onChanged: _enabled
                    ? (v) {
                        setState(() => _dormant = v);
                        _set('notif_dormant', v);
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
