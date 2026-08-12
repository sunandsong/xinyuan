import 'package:flutter_test/flutter_test.dart';
import 'package:xinyuan/version.dart';

void main() {
  group('versionLessThan（强更比较，弹错了就是把所有人锁在门外）', () {
    test('常规大小', () {
      expect(versionLessThan('1.0.0', '1.0.1'), isTrue);
      expect(versionLessThan('1.0.0', '1.1.0'), isTrue);
      expect(versionLessThan('1.9.0', '1.10.0'), isTrue); // 逐段数字比较，不是字符串比较
      expect(versionLessThan('2.0.0', '1.9.9'), isFalse);
    });

    test('相等不算小于——当前版本恰好等于 minVersion 时绝不能弹强更', () {
      expect(versionLessThan('1.0.0', '1.0.0'), isFalse);
    });

    test('段数不齐短的补 0', () {
      expect(versionLessThan('1.0', '1.0.1'), isTrue);
      expect(versionLessThan('1.0.0', '1.0'), isFalse);
      expect(versionLessThan('1', '1.0.0'), isFalse);
    });

    test('解析不了的段当 0，不抛异常', () {
      expect(versionLessThan('abc', '1.0.0'), isTrue);
      expect(versionLessThan('1.0.0', ''), isFalse); // minVersion 乱填不至于误伤
    });
  });
}
