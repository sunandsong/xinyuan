import 'dart:async';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';

/// 邮箱登录 / 注册表单：既用作弹层（我的页“登录/注册”），也用作 [LoginPage] 整页强制登录
class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.onSuccess});

  /// 登录/注册成功后的处理；不传则默认 Navigator.pop（弹层场景）
  final VoidCallback? onSuccess;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  final _code = TextEditingController();
  bool _register = false;
  bool _loading = false;
  bool _sendingCode = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    _code.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '请先填写邮箱');
      return;
    }
    setState(() {
      _sendingCode = true;
      _error = null;
    });
    try {
      await AuthApi.sendCode(email);
      if (!mounted) return;
      snack(context, '验证码已发送，请查收邮箱');
      setState(() => _cooldown = 60);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldown--);
        if (_cooldown <= 0) t.cancel();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '出错了，请重试');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppData.I.loginOrRegister(_email.text.trim(), _pwd.text,
          register: _register, code: _code.text.trim());
      if (!mounted) return;
      snack(context, _register ? '注册成功' : '登录成功');
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '出错了，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(TextEditingController c, String hint,
      {bool obscure = false, TextInputType? kb}) {
    return Container(
      decoration:
          BoxDecoration(color: T.field, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: kb,
        decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }

  Widget _codeField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
            child: _field(_code, '邮箱验证码', kb: TextInputType.number)),
        const SizedBox(width: 10),
        SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: (_sendingCode || _cooldown > 0) ? null : _sendCode,
            style: OutlinedButton.styleFrom(
                foregroundColor: T.accent,
                side: const BorderSide(color: T.accent)),
            child: Text(
                _cooldown > 0 ? '$_cooldown s' : (_sendingCode ? '发送中…' : '发送验证码'),
                style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_register ? '注册' : '登录',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text('登录后，心愿与勋章将云端同步',
            style: TextStyle(fontSize: 13.5, color: T.muted),
            textAlign: TextAlign.center),
        const SizedBox(height: 18),
        _field(_email, '邮箱', kb: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _field(_pwd, '密码（至少 6 位）', obscure: true),
        if (_register) ...[
          const SizedBox(height: 10),
          _codeField(),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_error!,
                style: const TextStyle(color: Color(0xFFE05A5A), fontSize: 13),
                textAlign: TextAlign.center),
          ),
        const SizedBox(height: 16),
        BigBtn(_loading ? '请稍候…' : (_register ? '注册并登录' : '登录'),
            onTap: _loading ? () {} : _submit),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() {
            _register = !_register;
            _error = null;
          }),
          child: Text(_register ? '已有账号？去登录' : '没有账号？去注册',
              style: const TextStyle(fontSize: 13.5, color: T.accent),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
