import 'dart:convert' show base64Encode;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api/api.dart';
import 'data.dart';
import 'ui.dart';

/// 心愿照片：选图 → 压缩 → 传云函数 → 把返回的地址挂到心愿上。
/// 上传走 /api/upload（云存储），所以换设备、重装 App 照片都还在。
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
      // 传之前先压：长边 1600、质量 80，一般能压到几百 KB，避免云函数请求体超限
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
  if (bytes.lengthInBytes > 4 * 1024 * 1024) {
    if (context.mounted) snack(context, '图片太大了，换一张小一点的');
    return null;
  }
  if (context.mounted) snack(context, '正在上传…');
  try {
    final url = await UploadApi.image(
      base64Data: base64Encode(bytes),
      mime: _mimeOf(file.name),
      wishId: wish.id,
    );
    AppData.I.addWishPhoto(wish, url);
    if (context.mounted) snack(context, '照片已存好');
    return url;
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
