import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api/api.dart';
import 'data.dart';
import 'ui.dart';

/// 心愿照片：选图 → 压缩 → 问后端换直传凭证 → 图片本体直接 PUT 给云存储
/// （不走我们自己的云函数——那层网关请求体限得很小，塞不下一张图）→ 把地址挂到心愿上。
final _picker = ImagePicker();

/// 选一张图并上传；成功返回图片地址，用户取消返回 null。
/// [fromCamera] 为 true 时直接开相机。
Future<String?> pickAndUploadWishPhoto(
  BuildContext context,
  Wish wish, {
  bool fromCamera = false,
}) async {
  if (!AppData.I.signedIn) {
    snack(context, '登录后才能上传照片');
    return null;
  }
  XFile? file;
  try {
    file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // 传之前先压一压，长边 1600、质量 80，别把手机相册里的原图整个传上去
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
  } catch (_) {
    if (context.mounted) snack(context, '打不开相册，请检查权限设置');
    return null;
  }
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (bytes.lengthInBytes > 8 * 1024 * 1024) {
    if (context.mounted) snack(context, '图片太大了，换一张小一点的');
    return null;
  }
  if (context.mounted) snack(context, '正在上传…');
  try {
    final ticket = await UploadApi.ticket(mime: _mimeOf(file.name));
    if (ticket.url.isEmpty) {
      // 本地 mock 模式没有真实云存储，跳过直传，方便本地联调界面
      if (context.mounted) snack(context, '本地调试模式暂不支持真实上传');
      return null;
    }
    final res = await http
        .put(Uri.parse(ticket.url), headers: ticket.headers, body: bytes)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (context.mounted) snack(context, '上传失败，请重试');
      return null;
    }
    AppData.I.addWishPhoto(wish, ticket.downloadUrl);
    if (context.mounted) snack(context, '照片已存好');
    return ticket.downloadUrl;
  } on ApiException catch (e) {
    if (context.mounted) snack(context, e.message);
  } catch (_) {
    if (context.mounted) snack(context, '上传失败，请重试');
  }
  return null;
}

String _mimeOf(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.heic')) return 'image/heic';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
