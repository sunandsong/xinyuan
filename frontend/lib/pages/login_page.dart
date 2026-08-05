import 'package:flutter/material.dart';
import '../api/api.dart';
import '../data.dart';
import '../theme.dart';
import '../ui.dart';

/// 账号密码登录 / 注册表单：既用作弹层（我的页“登录/注册”），也用作 [LoginPage] 整页强制登录
class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.onSuccess});

  /// 登录/注册成功后的处理；不传则默认 Navigator.pop（弹层场景）
  final VoidCallback? onSuccess;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _account = TextEditingController();
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();
  bool _register = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _account.dispose();
    _pwd.dispose();
    _pwd2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_register && _pwd.text != _pwd2.text) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppData.I.loginOrRegister(_account.text.trim(), _pwd.text,
          register: _register);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_register ? '注册' : '登录',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 18),
        _field(_account, '账号（3-20 位字母/数字/下划线）'),
        const SizedBox(height: 10),
        _field(_pwd, '密码（至少 6 位）', obscure: true),
        if (_register) ...[
          const SizedBox(height: 10),
          _field(_pwd2, '再输一次密码', obscure: true),
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
            _pwd2.clear();
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
