/// App 版本号，唯一真相。改版本时同步改 pubspec.yaml 的 version。
/// 「我的」页版本行、登录设备上报、强更比较都读这里。
const kAppVersion = '1.0.0';

/// semver 逐段比较：a < b 返回 true。段数不齐短的补 0；解析不了的段当 0。
bool versionLessThan(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}
