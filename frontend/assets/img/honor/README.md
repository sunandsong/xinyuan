# 荣誉奖杯图标

14 枚都已生成（504×504 透明底 PNG）。放这里就自动生效，不用改代码；
缺哪一枚，弹窗会自动退回金属奖章样式。

## 怎么改

图标是 `gen_trophies.py` 画出来的（SVG → Chrome headless 光栅化），不是手绘的。
统一杯身 + 底座保证成套感，每枚只换杯面徽记和主色（主色取自
`lib/pages/tree_page.dart` 里 `achievements()` 的颜色，压深盘上会自动提亮 42%）。

```bash
python3 gen_trophies.py . /tmp/svg    # 重新生成全部 14 枚
```

改某一枚就改对应的 `emblem_*()` 函数；加新成就就在 `ICONS` 里加一行，
slug 要和 `achievements()` 里那行最后的参数一致。

改完图标需要**重启 App**（热重载不会重新打包 assets）。

## 对照表

| 文件名 | 荣誉 | 条件 |
|---|---|---|
| `first_task.png` | 初试身手 | 完成第 1 个任务 |
| `task_10.png` | 渐入佳境 | 完成 10 个任务 |
| `task_100.png` | 百炼成钢 | 完成 100 个任务 |
| `streak_3.png` | 三日之约 | 连续 3 天 |
| `streak_7.png` | 七日成习 | 连续 7 天 |
| `streak_30.png` | 三十而立 | 连续 30 天 |
| `first_wish.png` | 首愿达成 | 点亮第 1 个心愿 |
| `wish_5.png` | 五愿成真 | 点亮 5 个心愿 |
| `wish_10.png` | 十全十美 | 点亮 10 个心愿 |
| `half_way.png` | 心愿过半 | 完成度 50% |
| `first_step.png` | 拆解行家 | 完成 1 个里程碑 |
| `first_photo.png` | 留下印记 | 传第 1 张照片 |
| `first_note.png` | 过程记录者 | 写第 1 条笔记 |
| `first_letter.png` | 时光旅人 | 写 1 封给未来的信 |
