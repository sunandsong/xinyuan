import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/api.dart';
import 'data.dart';
import 'ui.dart';

/// 心愿照片：选图 → 压缩 → 问后端换直传凭证 → 图片本体直接 PUT 给云存储
/// （不走我们自己的云函数——那层网关请求体限得很小，塞不下一张图）→ 把地址挂到心愿上。
///
/// 存的是去掉 ?sign= 的稳定链接（临时签名几小时就过期），展示时通过
/// /photo-urls 换新鲜临时链接，内存缓存一份。
final _picker = ImagePicker();

final _freshUrl = <String, String>{}; // 稳定链接 → 当前有效的临时链接
final _fetching = <String, Future<String?>>{}; // 进行中的请求去重

// ---------- 图片磁盘缓存 ----------
// 为什么要自己做：Image.network 只有内存缓存，冷启动必然重新下载；而且临时链接
// 每次带的签名都不一样（?sign=..&t=..），URL 字符串一变，内存缓存也命中不了，
// 于是每次进页面都要重下一遍 → 先显示兜底图再跳成真图，就是那一下闪。
// 这里按「去掉签名的稳定链接」缓存到磁盘，命中就直接读文件，不发任何网络请求。
//
// ponytail: 用系统临时目录，不引 path_provider/cached_network_image。
// 代价是系统存储紧张时可能被清掉——那就重新下一次，不影响正确性。
Directory? _cacheDir;
final _cachedFile = <String, File>{}; // 稳定链接 → 本地文件（内存索引，省 stat）
final _downloading = <String, Future<File?>>{}; // 同一张图并发请求去重

/// 稳定链接 → 确定性的文件名。不能用 String.hashCode：Dart 没保证它跨进程稳定，
/// 缓存会白失效。直接把路径里的非字母数字换成下划线，我们这些图路径本身就唯一。
String _cacheName(String stableUrl) {
  final path = Uri.tryParse(stableUrl)?.path ?? stableUrl;
  return path.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

Future<Directory> _ensureCacheDir() async {
  final d = _cacheDir ??= Directory('${Directory.systemTemp.path}/xy_img');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

/// 本地已缓存就返回文件，否则下载后返回；失败返回 null（调用方回落到网络/兜底图）
Future<File?> cachedImageFile(String stored) {
  final key = stored.split('?').first;
  final hit = _cachedFile[key];
  if (hit != null) return Future.value(hit);
  return _downloading[key] ??= () async {
    try {
      final dir = await _ensureCacheDir();
      final f = File('${dir.path}/${_cacheName(key)}');
      if (await f.exists() && await f.length() > 0) {
        _cachedFile[key] = f;
        return f;
      }
      final url = await freshPhotoUrl(key);
      if (url == null) return null;
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;
      // 先写临时文件再改名：中途失败不会留下半张图，下次还能重下
      final tmp = File('${f.path}.part');
      await tmp.writeAsBytes(r.bodyBytes);
      await tmp.rename(f.path);
      _cachedFile[key] = f;
      return f;
    } catch (_) {
      return null; // 缓存是加速手段，失败不该影响功能
    } finally {
      _downloading.remove(key);
    }
  }();
}

/// 把存的照片链接换成当前可访问的临时链接（带缓存；旧数据带的过期签名会被剥掉）
Future<String?> freshPhotoUrl(String stored) {
  final key = stored.split('?').first;
  final hit = _freshUrl[key];
  if (hit != null) return Future.value(hit);
  return _fetching[key] ??= () async {
    try {
      final r = await ApiClient.I.post('/photo-urls', {
        'urls': [key],
      });
      final u = (r['urls'] as Map?)?[key] as String?;
      if (u == null) debugPrint('[photo] no fresh url for $key, resp=$r');
      if (u != null) _freshUrl[key] = u;
      return u;
    } catch (e) {
      debugPrint('[photo] fresh url failed for $key: $e');
      return null;
    } finally {
      _fetching.remove(key);
    }
  }();
}

/// 心愿照片统一走这里渲染：先换新鲜链接再 Image.network。
/// [fallback] 加载失败时显示；[loading] 换链接/下载中显示，缺省用 fallback。
class WishPhoto extends StatelessWidget {
  const WishPhoto(
    this.stored, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.fallback,
    this.loading,
  });
  final String stored;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    // 走磁盘缓存：命中就直接读本地文件，一次网络都不发，也就没有「先兜底图
    // 再跳真图」的闪烁。没命中才下载（下载完同样落盘，下次就不闪了）。
    return FutureBuilder<File?>(
      future: cachedImageFile(stored),
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            // 文件被系统清了/内容坏了：删掉索引让下次重下，这次先显示兜底
            errorBuilder: (_, __, ___) {
              _cachedFile.remove(stored.split('?').first);
              return fallback;
            },
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return loading ?? fallback;
        }
        // 缓存拿不到（没网/下载失败）：退回原来的在线加载，别直接放弃
        return _networkFallback();
      },
    );
  }

  Widget _networkFallback() {
    return FutureBuilder<String?>(
      future: freshPhotoUrl(stored),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null) {
          return snap.connectionState == ConnectionState.done
              ? fallback
              : (loading ?? fallback);
        }
        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) {
            _freshUrl.remove(stored.split('?').first); // 可能又过期了，下次重取
            return fallback;
          },
          loadingBuilder: (_, child, p) =>
              p == null ? child : (loading ?? fallback),
        );
      },
    );
  }
}

/// 选一张图、压缩并直传云存储；成功返回稳定链接，取消/失败返回 null（内部已弹提示）。
/// [onPicked] 在选完图、开始上传前回调（用来亮"上传中"占位）。
Future<String?> pickAndUploadPhoto(
  BuildContext context, {
  bool fromCamera = false,
  double maxSide = 1280,
  int quality = 72,
  void Function()? onPicked,
}) async {
  if (!AppData.I.signedIn) {
    snack(context, '登录后才能上传照片');
    return null;
  }
  // 系统权限弹窗之前先说明场景；相机和相册是两个不同的系统权限，各自只问一次，
  // 问过就不再打扰（系统自己会记住授权结果，这个提示只是补场景说明）。
  final prefs = await SharedPreferences.getInstance();
  final explainedKey = fromCamera ? 'camera_perm_explained' : 'photo_perm_explained';
  if (!(prefs.getBool(explainedKey) ?? false)) {
    if (!context.mounted) return null;
    final proceed = await explainPermission(
      context,
      body: fromCamera
          ? '为了拍摄心愿封面/头像照片，需要访问你的相机。'
          : '为了选取心愿封面/头像图片，需要访问你的照片。',
    );
    if (!proceed) return null;
    await prefs.setBool(explainedKey, true);
    if (!context.mounted) return null;
  }
  XFile? file;
  try {
    file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // 传之前先压一压，别把原图整个传上去。长边 1280/质量 72：手机上看头图
      // 和缩略图都够用，体积比 1600/80 小一半以上——上行带宽实测只有几十 KB/s，
      // 每省 100KB 就是省一两秒
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
    );
  } catch (e) {
    debugPrint('[photo] pick failed: $e');
    if (context.mounted) snack(context, '打不开相册，请检查权限设置');
    return null;
  }
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (bytes.lengthInBytes > 8 * 1024 * 1024) {
    if (context.mounted) snack(context, '图片太大了，换一张小一点的');
    return null;
  }
  onPicked?.call();
  try {
    final ticket = await UploadApi.ticket(mime: _mimeOf(file.name));
    if (ticket.url.isEmpty) {
      if (context.mounted) snack(context, '拿不到上传凭证，请稍后重试');
      return null;
    }
    final res = await http
        .put(Uri.parse(ticket.url), headers: ticket.headers, body: bytes)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('[photo] COS PUT ${res.statusCode}: ${res.body}');
      if (context.mounted) snack(context, '上传失败，请重试');
      return null;
    }
    // 存稳定链接；刚拿到的带签名链接直接当缓存用，传完立刻能显示
    final stored = ticket.downloadUrl.split('?').first;
    _freshUrl[stored] = ticket.downloadUrl;
    return stored;
  } on ApiException catch (e) {
    debugPrint('[photo] api error: $e');
    if (context.mounted) snack(context, e.message);
  } catch (e) {
    debugPrint('[photo] upload failed: $e');
    if (context.mounted) snack(context, '上传失败，请重试');
  }
  return null;
}

/// 选一张图并挂到心愿上；成功返回图片地址，用户取消返回 null。
/// [fromCamera] 为 true 时直接开相机。
Future<String?> pickAndUploadWishPhoto(
  BuildContext context,
  Wish wish, {
  bool fromCamera = false,
}) async {
  try {
    final stored = await pickAndUploadPhoto(
      context,
      fromCamera: fromCamera,
      // 选完图立刻在照片区亮出"上传中"占位格——换凭证 + 直传要好几秒，别让人以为没反应
      onPicked: () => AppData.I.setPhotoUploading(wish.id),
    );
    if (stored != null) {
      AppData.I.addWishPhoto(wish, stored);
      if (context.mounted) snack(context, '照片已存好');
    }
    return stored;
  } finally {
    AppData.I.setPhotoUploading(null);
  }
}

/// 选一张图当头像：小尺寸压缩上传，成功后立即生效并同步云端
Future<String?> pickAndUploadAvatar(BuildContext context) async {
  final stored = await pickAndUploadPhoto(context, maxSide: 512, quality: 80);
  if (stored != null) {
    AppData.I.setAvatarPhoto(stored);
    if (context.mounted) snack(context, '头像已更新');
  }
  return stored;
}

String _mimeOf(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.heic')) return 'image/heic';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
