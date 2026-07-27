import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';
import 'login_page.dart';

/// 年度回顾海报
class AnnualPage extends StatelessWidget {
  const AnnualPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppData.I;
    final year = DateTime.now().year;
    final doneThisYear =
        data.doneWishes.where((w) => w.doneAt!.year == year).toList();
    final heroesRow = (doneThisYear.isEmpty
            ? data.doneWishes.take(3)
            : doneThisYear.take(3))
        .map((w) => w.hero ?? AppData.heroes[0])
        .toList();
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
          child: Column(
            children: [
              Row(
                children: [
                  PillBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context)),
                  const Expanded(
                    child: Center(
                      child: Text('年度回顾',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SheetCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$year',
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  color: T.accent,
                                  height: 1)),
                          const SizedBox(height: 10),
                          Text(
                              '你完成了${_cn(doneThisYear.length)}件\n很久以前想做的事',
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (final hero in heroesRow)
                                Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(right: 5),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: hero,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _stat('为心愿推进', '${data.pushedDaysThisYear} 天'),
                          _stat('完成的任务', '${data.doneTaskCount} 个'),
                          _stat('清单还剩', '${data.activeWishes.length} 件'),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text('心愿 App · 年度报告',
                                style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFFC0C2CB))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              BigBtn('保存长图 · 分享',
                  onTap: () => snack(context, '已保存到相册（演示）')),
            ],
          ),
        ),
      ),
    );
  }

  String _cn(int n) {
    const names = ['零', '一', '两', '三', '四', '五', '六', '七', '八', '九'];
    return n < names.length ? ' ${names[n]} ' : ' $n ';
  }

  Widget _stat(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: T.field))),
      child: Row(
        children: [
          Text(k, style: const TextStyle(fontSize: 15, color: T.muted)),
          const Spacer(),
          Text(v,
              style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

/// 时光胶囊：写给未来的信，全部来自云端真实数据
class CapsulePage extends StatelessWidget {
  const CapsulePage({super.key});

  void _write(BuildContext context) {
    if (!AppData.I.signedIn) {
      showBlurDialog(context, const LoginForm());
      return;
    }
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const WriteLetterPage()));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final letters = AppData.I.letters;
        return Scaffold(
          backgroundColor: T.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      PillBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.pop(context)),
                      const Expanded(
                        child: Center(
                          child: Text('时光胶囊',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 38),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: letters.isEmpty
                        ? Center(
                            child: Text(
                                AppData.I.signedIn ? '还没有写过信' : '登录后开始写信',
                                style: const TextStyle(
                                    fontSize: 14.5, color: T.muted)),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: letters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 11),
                            itemBuilder: (context, i) =>
                                _letterCard(letters[i]),
                          ),
                  ),
                  const SizedBox(height: 10),
                  BigBtn('写一封给未来的信',
                      bg: T.field,
                      fg: const Color(0xFF3A3A42),
                      onTap: () => _write(context)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _letterCard(Letter l) {
    final open = AppData.I.isLetterOpen(l);
    if (!open) {
      final sub =
          '封存中 · 距开启还有 ${l.openAt.difference(DateTime.now()).inDays.clamp(0, 999999)} 天';
      return SheetCard(
        child: Row(
          children: [
            _lockIcon(),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.title, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(fontSize: 15.5, color: T.muted)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Opacity(
      opacity: .68,
      child: SheetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _lockIcon(open: true),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.title, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text('已开启 · ${ymdDots(l.openAt)}',
                          style: const TextStyle(
                              fontSize: 15.5, color: T.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('「${l.content}」',
                style: const TextStyle(
                    fontSize: 15.5, height: 1.8, color: Color(0xFF5A5C66))),
          ],
        ),
      ),
    );
  }

  Widget _lockIcon({bool open = false}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: open ? T.field : T.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        open ? Icons.lock_open_rounded : Icons.lock_rounded,
        size: 18,
        color: open ? T.faint : T.accent,
      ),
    );
  }
}

/// 写一封时光胶囊信（整页）
class WriteLetterPage extends StatefulWidget {
  const WriteLetterPage({super.key});
  @override
  State<WriteLetterPage> createState() => _WriteLetterPageState();
}

class _WriteLetterPageState extends State<WriteLetterPage> {
  static const _emojis = [
    '😀', '😁', '😂', '🤣', '😊', '😍', '🥰', '😘', '😅', '😉', '😎', '🤔',
    '😴', '😭', '😢', '🥹', '👍', '👏', '🙌', '🎉', '❤️', '✨', '🌟', '🔥',
    '🌈', '☀️', '🌙', '⭐', '🍀', '🌸', '🌊', '🏔️', '☕', '🎂', '🎁', '📖',
    '✈️', '🏠', '💪', '🙏', '😇', '🥳',
  ];

  final _title = TextEditingController();
  final _content = TextEditingController();
  final _contentFocus = FocusNode();
  DateTime _openAt = DateTime.now().add(const Duration(days: 365));

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _insertEmoji(String emoji) {
    final text = _content.text;
    final sel = _content.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    _content.text = text.replaceRange(start, end, emoji);
    final pos = start + emoji.length;
    _content.selection = TextSelection.collapsed(offset: pos);
    _contentFocus.requestFocus();
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: T.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final e in _emojis)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _insertEmoji(e);
                  },
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
          child: Column(
            children: [
              Row(
                children: [
                  PillBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context)),
                  const Expanded(
                    child: Center(
                      child: Text('写一封信',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  GestureDetector(
                    onTap: _submit,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text('封存',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: T.accent)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    TextField(
                      controller: _title,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '信的标题，比如「给三十岁的你」',
                        hintStyle: TextStyle(
                            fontSize: 24,
                            color: T.faint,
                            fontWeight: FontWeight.w600),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _content,
                      focusNode: _contentFocus,
                      decoration: const InputDecoration(
                        hintText: '想对未来的自己说什么…',
                        hintStyle: TextStyle(fontSize: 17, color: T.faint),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 17, height: 1.6),
                      maxLines: null,
                      minLines: 6,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showEmojiPicker,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: T.field, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.emoji_emotions_outlined,
                            size: 19, color: T.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  decoration: BoxDecoration(
                      color: T.field, borderRadius: BorderRadius.circular(11)),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 19, color: T.accent),
                      const SizedBox(width: 9),
                      const Text('开启日期', style: TextStyle(fontSize: 15)),
                      const Spacer(),
                      Text(ymdDots(_openAt),
                          style: const TextStyle(
                              fontSize: 15,
                              color: T.accent,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openAt,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 50),
    );
    if (picked != null) setState(() => _openAt = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty) return;
    AppData.I.addLetter(title, content, _openAt);
    Navigator.pop(context);
  }
}
