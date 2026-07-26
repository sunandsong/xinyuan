import 'package:flutter/material.dart';

/// 设计 token —— 滴答蓝方案
class T {
  // 亮色（日常页）
  static const bg = Color(0xFFF2F3F7);
  static const card = Colors.white;
  static const ink = Color(0xFF1C1C21);
  static const muted = Color(0xFF8A8C98);
  static const faint = Color(0xFFA2A4AE);
  static const line = Color(0xFFE6E7EC);
  static const field = Color(0xFFF1F2F6);
  static const accent = Color(0xFF3EA983); // 蓝绿主题（偏绿松石）
  static const accentSoft = Color(0xFFE2F1EA);
  static const holiday = Color(0xFF35A46B);

  // 心愿色板（一个心愿一个颜色，灰 = 杂事）
  static const wishPalette = [
    Color(0xFFA8B8F8), // 蓝
    Color(0xFFF5D08C), // 黄
    Color(0xFFF09A9A), // 红
    Color(0xFFB8E0C8), // 绿
    Color(0xFFD8C0F0), // 紫
  ];
  static const grey = Color(0xFFC9CBD6);
  static const greyBar = Color(0xFFE2E3E8);

  // 暗色（高光页）
  static const darkBg = Color(0xFF0B1120);
  static const darkCard = Color(0xFF0F1626);
  static const gold = Color(0xFFF5C86B);
  static const darkMuted = Color(0xFF8FA0C0);
  static const branch1 = Color(0xFF33415E);
  static const branch2 = Color(0xFF45577E);
  static const branch3 = Color(0xFF56688F);
  static const bud = Color(0xFF3E4E74);

  static const plusGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4B84DB), Color(0xFF5EB87C)],
  );
  static const goldGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7D98C), Color(0xFFE8B341)],
  );
  static const goldTextGrad = LinearGradient(
    colors: [Color(0xFFFFE9B0), Color(0xFFE8B341), Color(0xFFFFF3CE)],
    stops: [0, .55, 1],
  );
  static const foilGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF7D98C),
      Color(0xFF6E5320),
      Color(0xFFF7D98C),
      Color(0xFF6E5320),
      Color(0xFFF7D98C),
    ],
    stops: [0, .3, .52, .78, 1],
  );

  // 柔和多层阴影 —— 卡片真正浮起
  static const shadowCard = [
    BoxShadow(
        color: Color(0x0A2A3550), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
        color: Color(0x0F2A3550), blurRadius: 16, offset: Offset(0, 8)),
  ];
  static const shadowDock = [
    BoxShadow(color: Color(0x1A2A3550), blurRadius: 20, offset: Offset(0, 6)),
  ];
}
