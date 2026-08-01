import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
      // 本地 mock 模式没有真实云存储，跳过直传，方便本地联调界面
      if (context.mounted) snack(context, '本地调试模式暂不支持真实上传');
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
  final stored =
      await pickAndUploadPhoto(context, maxSide: 512, quality: 80);
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
