// 景区坐标与就近匹配：打卡定位的核心逻辑
import 'package:flutter_test/flutter_test.dart';
import 'package:xinyuan/spot_geo.dart';

void main() {
  test('站在故宫：故宫最近，天坛也在附近列表里', () {
    final near = nearbySpots(39.92, 116.40);
    expect(near.first.$1, '故宫');
    expect(near.first.$2, lessThan(1));
    expect(near.map((e) => e.$1), contains('天坛'));
    expect(near.length, lessThanOrEqualTo(8));
    // 距离升序
    for (var i = 1; i < near.length; i++) {
      expect(near[i].$2, greaterThanOrEqualTo(near[i - 1].$2));
    }
  });

  test('大海中央：附近没有任何景区', () {
    expect(nearbySpots(20.0, 150.0), isEmpty);
  });

  test('跨省重名（天台山）：按距离取最近那处，列表不重复', () {
    // 邛崃天台山坐标附近打卡，列表里只该出现一个「天台山」
    final near = nearbySpots(30.36, 103.26, maxKm: 3000, limit: 400);
    expect(near.where((e) => e.$1 == '天台山').length, 1);
    expect(near.firstWhere((e) => e.$1 == '天台山').$2, lessThan(5),
        reason: '取的必须是近的四川那处，不是几百公里外的浙江那处');
  });

  test('坐标表没有意外的重复条目', () {
    // 跨省重名的景区（浙江/四川各有一个天台山）允许两条，其余必须唯一
    const knownDuals = {'天台山'};
    final counts = <String, int>{};
    for (final (name, _, _) in spotGeo) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final dups = counts.entries
        .where((e) => e.value > (knownDuals.contains(e.key) ? 2 : 1))
        .toList();
    expect(dups, isEmpty, reason: '坐标表不该有意外重复: $dups');
  });
}
