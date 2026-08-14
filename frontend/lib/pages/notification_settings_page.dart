import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data.dart';
import '../notification_scheduler.dart';
import '../theme.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('接收通知'),
            value: _enabled,
            onChanged: (v) {
              setState(() => _enabled = v);
              _set('notif_enabled', v);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('任务到期提醒'),
            value: _tasks,
            onChanged: _enabled
                ? (v) {
                    setState(() => _tasks = v);
                    _set('notif_tasks', v);
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('心愿期限提醒'),
            value: _wishes,
            onChanged: _enabled
                ? (v) {
                    setState(() => _wishes = v);
                    _set('notif_wishes', v);
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('时光胶囊开启提醒'),
            value: _letters,
            onChanged: _enabled
                ? (v) {
                    setState(() => _letters = v);
                    _set('notif_letters', v);
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('好久没来提醒'),
            value: _dormant,
            onChanged: _enabled
                ? (v) {
                    setState(() => _dormant = v);
                    _set('notif_dormant', v);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
