// 数据初始化脚本（Task 9）：把 App 内置的默认心愿、里程碑模板、成就文案、5A 景区库、
// 海报文案灌进对应的管理端内容集合。图片 url 一律留空，后续在管理端上传后再补。
//
// 数据来源（转成下面的 TS 常量，跟 App 端保持字面一致，不在运行时解析 .dart 源码）：
//   - frontend/lib/presets.dart      → LIFE_GOALS_50（取前 50，跟 App「小清单」口径一致）、GOAL_STEPS
//   - frontend/lib/spot_geo.dart     → SPOTS（按文件里的分省注释取 province，同名景区保留第一条）
//   - frontend/lib/share_poster.dart → TASK_SLOGANS / WISH_SLOGANS（_taskStyles/_wishStyles 的 slogan）
//   - frontend/lib/pages/tree_page.dart 的 achievements() → ACHV_DEFS（14 枚 slug/name/desc）
//
// 幂等：每个集合先查已有文档，按 keyField（title/slug/name）去重，已存在的跳过，可以放心重跑。
// hero_images 灌 5 张场景图（日出/海浪/山峦/星空/极光），跟 wish_pages.dart 的
// _defaultHeroes 一一对应。最初按简报留空，2026-08-15 图片全部上云后补上。
//
// 跑法：cd backend && npx ts-node scripts/seed-content.ts
// 凭证：本地脚本拿不到云函数运行时角色注入的凭证。脚本自己执行 `tcb secrets get --json`
// （需要先 `tcb login` 过一次，跟部署用的是同一个登录态）换当前登录态的临时 AKSK + sessionToken
// 初始化 SDK——这是本仓库其它一次性联调脚本（见 task-2/3 报告）验证过的方式，不用改生产代码，
// 也不用手动导出环境变量。临时凭证约 2 小时过期，脚本没跑完就重新执行一次即可（幂等，重跑安全）。

import { execSync } from 'child_process';

const ENV_ID = 'renshengqingdan-d8feva5q55d12bab';

function initDb() {
  const raw = execSync('tcb secrets get --json', { encoding: 'utf8' });
  const { secretId, secretKey, token } = JSON.parse(raw).data;
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const cloudbase = require('@cloudbase/node-sdk');
  const app = cloudbase.init({ env: ENV_ID, secretId, secretKey, sessionToken: token });
  return app.database();
}

/** App 内置人生必做清单前 50 条（frontend/lib/presets.dart 的 lifeGoals，取前 50——
 * 跟 App「小清单」口径一致，见该文件顶部注释）*/
const LIFE_GOALS_50: string[] = [
  "看一次日出",
  "去看一次海",
  "看一次极光",
  "独自旅行一次",
  "学会游泳",
  "读完 100 本书",
  "学会一门乐器",
  "存下人生第一个十万",
  "带爸妈去旅行一次",
  "完成一次长途徒步",
  "学会做三道拿手菜",
  "养成规律运动的习惯",
  "跑完一次五公里",
  "完成一次半程马拉松",
  "学一门外语到能对话",
  "写一封信给十年后的自己",
  "种一盆植物并养活它",
  "学会拍照与修图",
  "去看一次演唱会",
  "露营看一次星空",
  "学会开车拿到驾照",
  "独自看一场电影",
  "认真断舍离一次",
  "坚持记账一整年",
  "开始定投理财",
  "献一次血",
  "参加一次志愿服务",
  "学会一项手艺",
  "潜水看一次海底",
  "滑一次雪",
  "坐一次热气球",
  "看一次流星雨",
  "去沙漠看星空",
  "出国旅行一次",
  "环游一个国家",
  "学会一支舞",
  "写完一本日记",
  "完成一幅画",
  "亲手做一顿年夜饭",
  "陪爸妈过一个完整假期",
  "给自己认真办一次生日",
  "减重或增肌到理想状态",
  "戒掉一个坏习惯",
  "培养一个新爱好",
  "学会冥想与正念",
  "读完一部经典名著",
  "自己烤一次面包",
  "学会调一杯鸡尾酒",
  "办一次朋友聚会",
  "来一次说走就走的旅行",
];

/** 心愿 → 里程碑拆解模板（frontend/lib/presets.dart 的 goalSteps） */
const GOAL_STEPS: Array<{ title: string; steps: string[] }> = [
  { title: "看一次日出", steps: ["选好一个看日出的地方", "查日出时间、定好闹钟", "前一晚早点睡", "看到并拍下这一刻"] },
  { title: "去看一次海", steps: ["定城市和日期", "订好车票住宿", "出发", "在海边待满一整天"] },
  { title: "看一次极光", steps: ["选目的地和季节", "攒够预算", "订机票住宿", "看到极光"] },
  { title: "独自旅行一次", steps: ["选一个想去的城市", "请好假、订票", "列一份轻装行李清单", "一个人走完全程"] },
  { title: "学会游泳", steps: ["报名或找到能游的泳池", "敢把头埋进水里", "学会换气", "连续游完 50 米"] },
  { title: "读完 100 本书", steps: ["列一份想读的书单", "固定每天的阅读时间", "读完前 10 本", "读完 50 本", "读完第 100 本"] },
  { title: "学会一门乐器", steps: ["选定乐器并买/借一把", "找教程或老师", "练熟基本指法", "完整弹下来一首曲子"] },
  { title: "存下人生第一个十万", steps: ["算清每月能存多少", "开一个专门的账户", "存到 3 万", "存到 6 万", "存满 10 万"] },
  { title: "带爸妈去旅行一次", steps: ["问他们想去哪", "选一个不累的行程", "订票订住宿", "一起出发", "给他们拍一张合照"] },
  { title: "完成一次长途徒步", steps: ["选一条路线", "把装备配齐", "先走两次短途拉练", "完成全程"] },
  { title: "养成规律运动的习惯", steps: ["选一项能坚持的运动", "固定每周三次的时间", "坚持满一个月", "坚持满三个月"] },
  { title: "跑完一次五公里", steps: ["先能连续跑 1 公里", "跑到 3 公里", "跑完 5 公里不停"] },
  { title: "学一门外语到能对话", steps: ["选语言、定教材", "背下最常用的 500 词", "开始跟读和听力", "找人做一次真实对话"] },
  { title: "写一封信给十年后的自己", steps: ["想清楚要说什么", "写下来", "封存进时光胶囊"] },
  { title: "学会开车拿到驾照", steps: ["报名驾校", "通过科目一", "练车并通过科目二", "通过科目三、科目四", "拿到驾照"] },
  { title: "学会做三道拿手菜", steps: ["选定三道菜", "做熟第一道", "做熟第二道", "做熟第三道并请人来吃"] },
  { title: "减重或增肌到理想状态", steps: ["定一个具体数字和期限", "把饮食安排好", "坚持训练一个月", "达到目标并保持一个月"] },
  { title: "出国旅行一次", steps: ["办护照", "选国家、办签证", "订机票住宿", "出发", "平安回来"] },
  { title: "学会拍照与修图", steps: ["把相机或手机功能摸熟", "学构图与光线", "修完一组照片", "发一次自己的作品"] },
  { title: "完成一次公开演讲", steps: ["定题目", "写稿并逐字打磨", "至少排练三遍", "正式讲一次"] },
];

/** 任务成绩单海报文案（frontend/lib/share_poster.dart 的 _taskStyles.slogan） */
const TASK_SLOGANS: string[] = [
  "把想做的事\n一件件做完",
  "心里有光\n脚下有路",
  "日拱一卒\n功不唐捐",
  "每一天\n都算数",
  "说到\n就做到",
];

/** 心愿清单海报文案（frontend/lib/share_poster.dart 的 _wishStyles.slogan） */
const WISH_SLOGANS: string[] = [
  "心之所向\n素履以往",
  "愿望说出来\n就亮了",
  "翻过山\n就见到光",
  "奔赴热爱\n不负此生",
  "微光会聚成\n星海",
];

/** 心愿兜底头图（frontend/lib/pages/wish_pages.dart 的 _defaultHeroes，顺序要一致）
 * 对应 content/hero/ 下的 sunrise/ocean/mountains/stars/aurora.jpg */
/** 分享卡封面（frontend/lib/pages/share_page.dart）：
 * 宣告卡三张可左右滑 = _declareCovers，顺序要一致；凭证卡一张 = default_cover */
const DECLARE_COVERS: string[] = ["破晓登山", "火炬", "冲刺"];
/** 凭证卡（已点亮）封面四张，按心愿 id 稳定分配 */
const DONE_COVERS: string[] = ["暗夜星空", "晨曦山谷", "静海月夜", "极光雪原"];

const HERO_IMAGES: string[] = ["日出", "海浪", "山峦", "星空", "极光"];

/** 心愿达成海报文案（配 content/posters/done1-4.jpg，四张达成主题图：
 * 登顶云海 / 抵达海边 / 晨光窗边 / 星空草地） */
const DONE_SLOGANS: string[] = [
  "这一天\n终于到了",
  "想去的地方\n我到了",
  "等了很久\n就是今天",
  "又点亮了\n一个心愿",
];

/** 成就定义（frontend/lib/pages/tree_page.dart 的 achievements() 函数体，slug/name/desc） */
const ACHV_DEFS: Array<{ slug: string; name: string; desc: string }> = [
  { slug: "first_task", name: "初试身手", desc: "完成第 1 个任务" },
  { slug: "task_10", name: "渐入佳境", desc: "完成 10 个任务" },
  { slug: "task_100", name: "百炼成钢", desc: "完成 100 个任务" },
  { slug: "streak_3", name: "三日之约", desc: "连续 3 天完成任务" },
  { slug: "streak_7", name: "七日成习", desc: "连续 7 天完成任务" },
  { slug: "streak_30", name: "三十而立", desc: "连续 30 天完成任务" },
  { slug: "first_wish", name: "首愿达成", desc: "点亮第 1 个心愿" },
  { slug: "wish_5", name: "五愿成真", desc: "点亮 5 个心愿" },
  { slug: "wish_10", name: "十全十美", desc: "点亮 10 个心愿" },
  { slug: "half_way", name: "心愿过半", desc: "清单完成度达到 50%" },
  { slug: "first_step", name: "拆解行家", desc: "完成 1 个心愿里程碑" },
  { slug: "first_photo", name: "留下印记", desc: "给心愿传第 1 张照片" },
  { slug: "first_note", name: "过程记录者", desc: "写下第 1 条心愿笔记" },
  { slug: "first_letter", name: "时光旅人", desc: "写 1 封给未来的信" },
];

/** 5A 景区库（frontend/lib/spot_geo.dart 的 spotGeo，按注释分省；同名只保留第一条，
 * 跟该文件里「跨省重名各自打卡取最近」的口径一致）—— 共 352 条 */
const SPOTS: Array<{ name: string; lat: number; lng: number; province: string }> = [
  { name: "故宫", lat: 39.92, lng: 116.4, province: "北京" },
  { name: "天坛", lat: 39.88, lng: 116.41, province: "北京" },
  { name: "颐和园", lat: 39.99, lng: 116.27, province: "北京" },
  { name: "八达岭长城", lat: 40.36, lng: 116.02, province: "北京" },
  { name: "明十三陵", lat: 40.25, lng: 116.23, province: "北京" },
  { name: "恭王府", lat: 39.94, lng: 116.38, province: "北京" },
  { name: "奥林匹克公园", lat: 40.0, lng: 116.39, province: "北京" },
  { name: "圆明园", lat: 40.01, lng: 116.3, province: "北京" },
  { name: "大运河", lat: 39.9, lng: 116.66, province: "北京" },
  { name: "古文化街", lat: 39.15, lng: 117.19, province: "天津" },
  { name: "盘山", lat: 40.09, lng: 117.26, province: "天津" },
  { name: "山海关", lat: 40.01, lng: 119.75, province: "河北" },
  { name: "白洋淀", lat: 38.93, lng: 116.0, province: "河北" },
  { name: "野三坡", lat: 39.68, lng: 115.44, province: "河北" },
  { name: "白石山", lat: 39.19, lng: 114.72, province: "河北" },
  { name: "清西陵", lat: 39.35, lng: 115.34, province: "河北" },
  { name: "避暑山庄", lat: 40.99, lng: 117.94, province: "河北" },
  { name: "金山岭长城", lat: 40.69, lng: 117.24, province: "河北" },
  { name: "西柏坡", lat: 38.35, lng: 113.94, province: "河北" },
  { name: "清东陵", lat: 40.19, lng: 117.66, province: "河北" },
  { name: "唐山南湖", lat: 39.6, lng: 118.17, province: "河北" },
  { name: "娲皇宫", lat: 36.58, lng: 113.65, province: "河北" },
  { name: "广府古城", lat: 36.68, lng: 114.75, province: "河北" },
  { name: "衡水湖", lat: 37.62, lng: 115.63, province: "河北" },
  { name: "云冈石窟", lat: 40.11, lng: 113.13, province: "山西" },
  { name: "五台山", lat: 39.0, lng: 113.6, province: "山西" },
  { name: "皇城相府", lat: 35.5, lng: 112.51, province: "山西" },
  { name: "绵山", lat: 36.93, lng: 111.94, province: "山西" },
  { name: "平遥古城", lat: 37.2, lng: 112.18, province: "山西" },
  { name: "雁门关", lat: 39.18, lng: 112.86, province: "山西" },
  { name: "洪洞大槐树", lat: 36.26, lng: 111.67, province: "山西" },
  { name: "太行山大峡谷", lat: 36.05, lng: 113.42, province: "山西" },
  { name: "云丘山", lat: 35.87, lng: 110.98, province: "山西" },
  { name: "壶口瀑布", lat: 36.14, lng: 110.44, province: "山西" },
  { name: "晋祠", lat: 37.71, lng: 112.44, province: "山西" },
  { name: "乔家大院", lat: 37.42, lng: 112.42, province: "山西" },
  { name: "响沙湾", lat: 40.2, lng: 110.05, province: "内蒙古" },
  { name: "成吉思汗陵", lat: 39.37, lng: 109.79, province: "内蒙古" },
  { name: "满洲里", lat: 49.6, lng: 117.38, province: "内蒙古" },
  { name: "阿尔山", lat: 47.18, lng: 119.94, province: "内蒙古" },
  { name: "阿斯哈图石阵", lat: 44.08, lng: 117.7, province: "内蒙古" },
  { name: "额济纳胡杨林", lat: 41.97, lng: 101.07, province: "内蒙古" },
  { name: "呼伦贝尔大草原", lat: 49.32, lng: 119.6, province: "内蒙古" },
  { name: "老牛湾", lat: 39.58, lng: 111.35, province: "内蒙古" },
  { name: "沈阳植物园", lat: 41.87, lng: 123.62, province: "辽宁" },
  { name: "老虎滩", lat: 38.87, lng: 121.68, province: "辽宁" },
  { name: "金石滩", lat: 39.08, lng: 122.01, province: "辽宁" },
  { name: "本溪水洞", lat: 41.33, lng: 124.08, province: "辽宁" },
  { name: "千山", lat: 41.03, lng: 123.13, province: "辽宁" },
  { name: "红海滩", lat: 40.9, lng: 121.79, province: "辽宁" },
  { name: "五女山", lat: 41.31, lng: 125.41, province: "辽宁" },
  { name: "伪满皇宫", lat: 43.91, lng: 125.34, province: "吉林" },
  { name: "长白山", lat: 42.02, lng: 128.06, province: "吉林" },
  { name: "净月潭", lat: 43.79, lng: 125.46, province: "吉林" },
  { name: "长影世纪城", lat: 43.8, lng: 125.48, province: "吉林" },
  { name: "六鼎山", lat: 43.31, lng: 128.24, province: "吉林" },
  { name: "长春雕塑公园", lat: 43.83, lng: 125.31, province: "吉林" },
  { name: "高句丽", lat: 41.13, lng: 126.19, province: "吉林" },
  { name: "查干湖", lat: 45.28, lng: 124.27, province: "吉林" },
  { name: "嫩江湾", lat: 45.51, lng: 124.29, province: "吉林" },
  { name: "太阳岛", lat: 45.79, lng: 126.61, province: "黑龙江" },
  { name: "五大连池", lat: 48.65, lng: 126.13, province: "黑龙江" },
  { name: "镜泊湖", lat: 43.9, lng: 128.95, province: "黑龙江" },
  { name: "汤旺河", lat: 48.45, lng: 129.57, province: "黑龙江" },
  { name: "北极村", lat: 53.48, lng: 122.36, province: "黑龙江" },
  { name: "虎头", lat: 45.98, lng: 133.65, province: "黑龙江" },
  { name: "扎龙", lat: 47.2, lng: 124.24, province: "黑龙江" },
  { name: "东方明珠", lat: 31.24, lng: 121.49, province: "上海" },
  { name: "上海野生动物园", lat: 31.05, lng: 121.72, province: "上海" },
  { name: "上海科技馆", lat: 31.22, lng: 121.54, province: "上海" },
  { name: "一大会址", lat: 31.22, lng: 121.47, province: "上海" },
  { name: "明珠湖", lat: 31.56, lng: 121.24, province: "上海" },
  { name: "中山陵", lat: 32.06, lng: 118.85, province: "江苏" },
  { name: "无锡影视基地", lat: 31.51, lng: 120.24, province: "江苏" },
  { name: "苏州园林", lat: 31.32, lng: 120.63, province: "江苏" },
  { name: "周庄", lat: 31.11, lng: 120.85, province: "江苏" },
  { name: "灵山大佛", lat: 31.43, lng: 120.09, province: "江苏" },
  { name: "瘦西湖", lat: 32.42, lng: 119.42, province: "江苏" },
  { name: "同里", lat: 31.16, lng: 120.72, province: "江苏" },
  { name: "金鸡湖", lat: 31.31, lng: 120.71, province: "江苏" },
  { name: "太湖", lat: 31.15, lng: 120.42, province: "江苏" },
  { name: "沙家浜", lat: 31.6, lng: 120.79, province: "江苏" },
  { name: "中华恐龙园", lat: 31.83, lng: 119.98, province: "江苏" },
  { name: "天目湖", lat: 31.36, lng: 119.48, province: "江苏" },
  { name: "淹城", lat: 31.72, lng: 119.93, province: "江苏" },
  { name: "濠河", lat: 32.01, lng: 120.86, province: "江苏" },
  { name: "溱湖", lat: 32.55, lng: 120.1, province: "江苏" },
  { name: "周恩来故里", lat: 33.5, lng: 119.14, province: "江苏" },
  { name: "大丰麋鹿园", lat: 33.03, lng: 120.81, province: "江苏" },
  { name: "云龙湖", lat: 34.24, lng: 117.17, province: "江苏" },
  { name: "花果山", lat: 34.65, lng: 119.28, province: "江苏" },
  { name: "连岛", lat: 34.77, lng: 119.46, province: "江苏" },
  { name: "洪泽湖湿地", lat: 33.36, lng: 118.28, province: "江苏" },
  { name: "惠山古镇", lat: 31.59, lng: 120.27, province: "江苏" },
  { name: "西湖", lat: 30.24, lng: 120.14, province: "浙江" },
  { name: "西溪湿地", lat: 30.27, lng: 120.06, province: "浙江" },
  { name: "千岛湖", lat: 29.6, lng: 119.02, province: "浙江" },
  { name: "雁荡山", lat: 28.37, lng: 121.06, province: "浙江" },
  { name: "普陀山", lat: 29.99, lng: 122.39, province: "浙江" },
  { name: "乌镇", lat: 30.74, lng: 120.49, province: "浙江" },
  { name: "嘉兴南湖", lat: 30.75, lng: 120.77, province: "浙江" },
  { name: "西塘", lat: 30.94, lng: 120.89, province: "浙江" },
  { name: "溪口", lat: 29.65, lng: 121.24, province: "浙江" },
  { name: "天一阁", lat: 29.87, lng: 121.53, province: "浙江" },
  { name: "鲁迅故里", lat: 29.99, lng: 120.58, province: "浙江" },
  { name: "横店影视城", lat: 29.16, lng: 120.3, province: "浙江" },
  { name: "金华双龙洞", lat: 29.15, lng: 119.62, province: "浙江" },
  { name: "根宫佛国", lat: 29.14, lng: 118.4, province: "浙江" },
  { name: "江郎山", lat: 28.55, lng: 118.56, province: "浙江" },
  { name: "南浔", lat: 30.87, lng: 120.42, province: "浙江" },
  { name: "天台山", lat: 29.18, lng: 121.04, province: "浙江" },
  { name: "神仙居", lat: 28.68, lng: 120.62, province: "浙江" },
  { name: "刘伯温故里", lat: 27.86, lng: 119.98, province: "浙江" },
  { name: "仙都", lat: 28.68, lng: 120.09, province: "浙江" },
  { name: "云和梯田", lat: 28.06, lng: 119.51, province: "浙江" },
  { name: "黄山", lat: 30.13, lng: 118.17, province: "安徽" },
  { name: "宏村", lat: 30.0, lng: 117.98, province: "安徽" },
  { name: "古徽州", lat: 29.87, lng: 118.44, province: "安徽" },
  { name: "九华山", lat: 30.48, lng: 117.8, province: "安徽" },
  { name: "天柱山", lat: 30.74, lng: 116.45, province: "安徽" },
  { name: "万佛湖", lat: 31.26, lng: 116.77, province: "安徽" },
  { name: "龙川", lat: 30.05, lng: 118.66, province: "安徽" },
  { name: "八里河", lat: 32.55, lng: 116.3, province: "安徽" },
  { name: "三河古镇", lat: 31.53, lng: 117.24, province: "安徽" },
  { name: "芜湖方特", lat: 31.42, lng: 118.45, province: "安徽" },
  { name: "采石矶", lat: 31.66, lng: 118.47, province: "安徽" },
  { name: "琅琊山", lat: 32.28, lng: 118.29, province: "安徽" },
  { name: "鼓浪屿", lat: 24.45, lng: 118.06, province: "福建" },
  { name: "武夷山", lat: 27.67, lng: 118.0, province: "福建" },
  { name: "永定土楼", lat: 24.63, lng: 116.98, province: "福建" },
  { name: "古田会议旧址", lat: 25.16, lng: 116.83, province: "福建" },
  { name: "泰宁", lat: 26.9, lng: 117.18, province: "福建" },
  { name: "清源山", lat: 24.95, lng: 118.6, province: "福建" },
  { name: "白水洋", lat: 26.94, lng: 118.9, province: "福建" },
  { name: "太姥山", lat: 27.11, lng: 120.19, province: "福建" },
  { name: "三坊七巷", lat: 26.08, lng: 119.29, province: "福建" },
  { name: "厦门植物园", lat: 24.45, lng: 118.1, province: "福建" },
  { name: "湄洲岛", lat: 25.06, lng: 119.1, province: "福建" },
  { name: "冠豸山", lat: 25.72, lng: 116.78, province: "福建" },
  { name: "庐山", lat: 29.56, lng: 115.98, province: "江西" },
  { name: "庐山西海", lat: 29.18, lng: 115.11, province: "江西" },
  { name: "井冈山", lat: 26.57, lng: 114.16, province: "江西" },
  { name: "三清山", lat: 28.9, lng: 118.06, province: "江西" },
  { name: "婺源", lat: 29.28, lng: 117.98, province: "江西" },
  { name: "篁岭", lat: 29.21, lng: 117.93, province: "江西" },
  { name: "龟峰", lat: 28.36, lng: 117.42, province: "江西" },
  { name: "龙虎山", lat: 28.06, lng: 117.02, province: "江西" },
  { name: "景德镇古窑", lat: 29.27, lng: 117.19, province: "江西" },
  { name: "滕王阁", lat: 28.68, lng: 115.88, province: "江西" },
  { name: "武功山", lat: 27.46, lng: 114.17, province: "江西" },
  { name: "瑞金", lat: 25.88, lng: 116.03, province: "江西" },
  { name: "三百山", lat: 25.09, lng: 115.42, province: "江西" },
  { name: "明月山", lat: 27.6, lng: 114.31, province: "江西" },
  { name: "大觉山", lat: 27.71, lng: 117.06, province: "江西" },
  { name: "蓬莱阁", lat: 37.83, lng: 120.75, province: "山东" },
  { name: "龙口南山", lat: 37.61, lng: 120.48, province: "山东" },
  { name: "三孔", lat: 35.6, lng: 116.99, province: "山东" },
  { name: "微山湖", lat: 34.81, lng: 117.13, province: "山东" },
  { name: "泰山", lat: 36.25, lng: 117.1, province: "山东" },
  { name: "崂山", lat: 36.19, lng: 120.62, province: "山东" },
  { name: "青岛奥帆", lat: 36.05, lng: 120.38, province: "山东" },
  { name: "刘公岛", lat: 37.5, lng: 122.19, province: "山东" },
  { name: "华夏城", lat: 37.44, lng: 122.1, province: "山东" },
  { name: "台儿庄古城", lat: 34.56, lng: 117.73, province: "山东" },
  { name: "趵突泉", lat: 36.66, lng: 117.02, province: "山东" },
  { name: "沂蒙山", lat: 35.55, lng: 117.9, province: "山东" },
  { name: "地下大峡谷", lat: 35.69, lng: 118.53, province: "山东" },
  { name: "青州古城", lat: 36.68, lng: 118.48, province: "山东" },
  { name: "黄河口", lat: 37.76, lng: 119.15, province: "山东" },
  { name: "周村古商城", lat: 36.8, lng: 117.85, province: "山东" },
  { name: "少林寺", lat: 34.51, lng: 112.94, province: "河南" },
  { name: "龙门石窟", lat: 34.56, lng: 112.47, province: "河南" },
  { name: "白云山", lat: 33.75, lng: 112.02, province: "河南" },
  { name: "老君山", lat: 33.75, lng: 111.64, province: "河南" },
  { name: "龙潭大峡谷", lat: 34.91, lng: 112.09, province: "河南" },
  { name: "云台山", lat: 35.42, lng: 113.4, province: "河南" },
  { name: "清明上河园", lat: 34.81, lng: 114.34, province: "河南" },
  { name: "殷墟", lat: 36.12, lng: 114.31, province: "河南" },
  { name: "红旗渠", lat: 36.08, lng: 113.82, province: "河南" },
  { name: "尧山", lat: 33.75, lng: 112.5, province: "河南" },
  { name: "老界岭", lat: 33.55, lng: 111.4, province: "河南" },
  { name: "嵖岈山", lat: 33.09, lng: 113.82, province: "河南" },
  { name: "芒砀山", lat: 34.14, lng: 116.4, province: "河南" },
  { name: "八里沟", lat: 35.63, lng: 113.6, province: "河南" },
  { name: "宝泉", lat: 35.62, lng: 113.53, province: "河南" },
  { name: "鸡公山", lat: 31.8, lng: 114.09, province: "河南" },
  { name: "太昊陵", lat: 33.73, lng: 114.87, province: "河南" },
  { name: "黄鹤楼", lat: 30.55, lng: 114.3, province: "湖北" },
  { name: "东湖", lat: 30.56, lng: 114.41, province: "湖北" },
  { name: "木兰天池", lat: 31.06, lng: 114.32, province: "湖北" },
  { name: "三峡大坝", lat: 30.82, lng: 111.0, province: "湖北" },
  { name: "三峡人家", lat: 30.76, lng: 111.11, province: "湖北" },
  { name: "三峡大瀑布", lat: 30.93, lng: 111.19, province: "湖北" },
  { name: "清江画廊", lat: 30.47, lng: 111.18, province: "湖北" },
  { name: "武当山", lat: 32.4, lng: 111.0, province: "湖北" },
  { name: "神农溪", lat: 31.04, lng: 110.34, province: "湖北" },
  { name: "恩施大峡谷", lat: 30.55, lng: 109.24, province: "湖北" },
  { name: "腾龙洞", lat: 30.31, lng: 108.98, province: "湖北" },
  { name: "神农架", lat: 31.46, lng: 110.4, province: "湖北" },
  { name: "赤壁古战场", lat: 29.85, lng: 113.62, province: "湖北" },
  { name: "古隆中", lat: 32.03, lng: 112.04, province: "湖北" },
  { name: "明显陵", lat: 31.21, lng: 112.63, province: "湖北" },
  { name: "龟峰山", lat: 31.25, lng: 115.24, province: "湖北" },
  { name: "衡山", lat: 27.25, lng: 112.65, province: "湖南" },
  { name: "武陵源", lat: 29.35, lng: 110.53, province: "湖南" },
  { name: "岳麓山", lat: 28.18, lng: 112.94, province: "湖南" },
  { name: "花明楼", lat: 28.15, lng: 112.62, province: "湖南" },
  { name: "岳阳楼", lat: 29.37, lng: 113.1, province: "湖南" },
  { name: "韶山", lat: 27.92, lng: 112.53, province: "湖南" },
  { name: "东江湖", lat: 25.98, lng: 113.45, province: "湖南" },
  { name: "崀山", lat: 26.38, lng: 110.8, province: "湖南" },
  { name: "炎帝陵", lat: 26.3, lng: 113.86, province: "湖南" },
  { name: "桃花源", lat: 28.8, lng: 111.49, province: "湖南" },
  { name: "矮寨", lat: 28.35, lng: 109.66, province: "湖南" },
  { name: "凤凰古城", lat: 27.95, lng: 109.6, province: "湖南" },
  { name: "长隆", lat: 22.99, lng: 113.32, province: "广东" },
  { name: "广州白云山", lat: 23.17, lng: 113.29, province: "广东" },
  { name: "华侨城", lat: 22.54, lng: 113.98, province: "广东" },
  { name: "观澜湖", lat: 22.72, lng: 114.04, province: "广东" },
  { name: "西樵山", lat: 22.94, lng: 112.96, province: "广东" },
  { name: "长鹿", lat: 22.8, lng: 113.28, province: "广东" },
  { name: "丹霞山", lat: 25.02, lng: 113.74, province: "广东" },
  { name: "雁南飞", lat: 24.42, lng: 116.16, province: "广东" },
  { name: "罗浮山", lat: 23.27, lng: 114.03, province: "广东" },
  { name: "惠州西湖", lat: 23.1, lng: 114.4, province: "广东" },
  { name: "孙中山故里", lat: 22.45, lng: 113.55, province: "广东" },
  { name: "开平碉楼", lat: 22.3, lng: 112.6, province: "广东" },
  { name: "海陵岛", lat: 21.6, lng: 111.85, province: "广东" },
  { name: "肇庆星湖", lat: 23.06, lng: 112.47, province: "广东" },
  { name: "连州地下河", lat: 24.94, lng: 112.44, province: "广东" },
  { name: "万绿湖", lat: 23.68, lng: 114.62, province: "广东" },
  { name: "漓江", lat: 24.95, lng: 110.45, province: "广西" },
  { name: "乐满地", lat: 25.62, lng: 110.64, province: "广西" },
  { name: "独秀峰", lat: 25.28, lng: 110.3, province: "广西" },
  { name: "两江四湖", lat: 25.27, lng: 110.29, province: "广西" },
  { name: "德天瀑布", lat: 22.85, lng: 106.65, province: "广西" },
  { name: "花山岩画", lat: 22.25, lng: 107.06, province: "广西" },
  { name: "百色起义纪念园", lat: 23.9, lng: 106.62, province: "广西" },
  { name: "青秀山", lat: 22.79, lng: 108.38, province: "广西" },
  { name: "涠洲岛", lat: 21.03, lng: 109.11, province: "广西" },
  { name: "黄姚古镇", lat: 24.25, lng: 111.2, province: "广西" },
  { name: "程阳八寨", lat: 25.9, lng: 109.6, province: "广西" },
  { name: "三亚南山", lat: 18.3, lng: 109.17, province: "海南" },
  { name: "大小洞天", lat: 18.3, lng: 109.11, province: "海南" },
  { name: "蜈支洲岛", lat: 18.31, lng: 109.77, province: "海南" },
  { name: "天涯海角", lat: 18.29, lng: 109.34, province: "海南" },
  { name: "分界洲岛", lat: 18.59, lng: 110.19, province: "海南" },
  { name: "呀诺达", lat: 18.38, lng: 109.65, province: "海南" },
  { name: "槟榔谷", lat: 18.39, lng: 109.6, province: "海南" },
  { name: "大足石刻", lat: 29.7, lng: 105.72, province: "重庆" },
  { name: "小三峡", lat: 31.07, lng: 109.88, province: "重庆" },
  { name: "武隆喀斯特", lat: 29.38, lng: 107.78, province: "重庆" },
  { name: "金佛山", lat: 29.02, lng: 107.18, province: "重庆" },
  { name: "酉阳桃花源", lat: 28.84, lng: 108.77, province: "重庆" },
  { name: "黑山谷", lat: 28.88, lng: 106.95, province: "重庆" },
  { name: "四面山", lat: 28.65, lng: 106.4, province: "重庆" },
  { name: "云阳龙缸", lat: 30.75, lng: 108.85, province: "重庆" },
  { name: "阿依河", lat: 29.2, lng: 108.15, province: "重庆" },
  { name: "濯水古镇", lat: 29.36, lng: 108.82, province: "重庆" },
  { name: "白帝城", lat: 31.05, lng: 109.58, province: "重庆" },
  { name: "武陵山大裂谷", lat: 29.56, lng: 107.3, province: "重庆" },
  { name: "都江堰", lat: 31.0, lng: 103.61, province: "四川" },
  { name: "峨眉山", lat: 29.55, lng: 103.34, province: "四川" },
  { name: "乐山大佛", lat: 29.55, lng: 103.77, province: "四川" },
  { name: "九寨沟", lat: 33.16, lng: 103.92, province: "四川" },
  { name: "黄龙", lat: 32.75, lng: 103.82, province: "四川" },
  { name: "汶川", lat: 31.06, lng: 103.49, province: "四川" },
  { name: "四姑娘山", lat: 31.1, lng: 102.87, province: "四川" },
  { name: "阆中古城", lat: 31.56, lng: 105.97, province: "四川" },
  { name: "朱德故里", lat: 31.43, lng: 106.67, province: "四川" },
  { name: "北川羌城", lat: 31.83, lng: 104.46, province: "四川" },
  { name: "邓小平故里", lat: 30.53, lng: 106.62, province: "四川" },
  { name: "剑门关", lat: 32.22, lng: 105.57, province: "四川" },
  { name: "海螺沟", lat: 29.58, lng: 102.05, province: "四川" },
  { name: "稻城亚丁", lat: 28.43, lng: 100.33, province: "四川" },
  { name: "碧峰峡", lat: 30.08, lng: 103.03, province: "四川" },
  { name: "光雾山", lat: 32.7, lng: 106.8, province: "四川" },
  { name: "安仁古镇", lat: 30.49, lng: 103.46, province: "四川" },
  { name: "黄果树", lat: 25.99, lng: 105.68, province: "贵州" },
  { name: "龙宫", lat: 26.12, lng: 105.95, province: "贵州" },
  { name: "百里杜鹃", lat: 27.24, lng: 105.87, province: "贵州" },
  { name: "织金洞", lat: 26.66, lng: 105.79, province: "贵州" },
  { name: "荔波樟江", lat: 25.25, lng: 107.72, province: "贵州" },
  { name: "青岩古镇", lat: 26.32, lng: 106.68, province: "贵州" },
  { name: "梵净山", lat: 27.91, lng: 108.7, province: "贵州" },
  { name: "镇远古城", lat: 27.05, lng: 108.42, province: "贵州" },
  { name: "赤水丹霞", lat: 28.47, lng: 105.8, province: "贵州" },
  { name: "万峰林", lat: 24.99, lng: 104.92, province: "贵州" },
  { name: "石林", lat: 24.77, lng: 103.34, province: "云南" },
  { name: "昆明世博园", lat: 25.08, lng: 102.77, province: "云南" },
  { name: "玉龙雪山", lat: 27.1, lng: 100.2, province: "云南" },
  { name: "丽江古城", lat: 26.87, lng: 100.23, province: "云南" },
  { name: "崇圣寺三塔", lat: 25.68, lng: 100.15, province: "云南" },
  { name: "西双版纳植物园", lat: 21.92, lng: 101.27, province: "云南" },
  { name: "普达措", lat: 27.85, lng: 99.95, province: "云南" },
  { name: "腾冲热海", lat: 24.97, lng: 98.47, province: "云南" },
  { name: "和顺古镇", lat: 24.99, lng: 98.43, province: "云南" },
  { name: "普者黑", lat: 24.1, lng: 104.11, province: "云南" },
  { name: "布达拉宫", lat: 29.66, lng: 91.12, province: "西藏" },
  { name: "大昭寺", lat: 29.65, lng: 91.13, province: "西藏" },
  { name: "巴松措", lat: 29.99, lng: 93.94, province: "西藏" },
  { name: "雅鲁藏布大峡谷", lat: 29.61, lng: 94.9, province: "西藏" },
  { name: "扎什伦布寺", lat: 29.26, lng: 88.87, province: "西藏" },
  { name: "兵马俑", lat: 34.38, lng: 109.28, province: "陕西" },
  { name: "华清池", lat: 34.36, lng: 109.21, province: "陕西" },
  { name: "大雁塔", lat: 34.22, lng: 108.96, province: "陕西" },
  { name: "西安城墙", lat: 34.26, lng: 108.94, province: "陕西" },
  { name: "大明宫", lat: 34.29, lng: 108.96, province: "陕西" },
  { name: "黄帝陵", lat: 35.58, lng: 109.26, province: "陕西" },
  { name: "延安革命纪念地", lat: 36.6, lng: 109.49, province: "陕西" },
  { name: "乾坤湾", lat: 36.8, lng: 110.45, province: "陕西" },
  { name: "华山", lat: 34.48, lng: 110.08, province: "陕西" },
  { name: "法门寺", lat: 34.44, lng: 107.9, province: "陕西" },
  { name: "太白山", lat: 34.06, lng: 107.81, province: "陕西" },
  { name: "金丝峡", lat: 33.4, lng: 110.7, province: "陕西" },
  { name: "乾陵", lat: 34.58, lng: 108.22, province: "陕西" },
  { name: "嘉峪关", lat: 39.81, lng: 98.22, province: "甘肃" },
  { name: "崆峒山", lat: 35.55, lng: 106.52, province: "甘肃" },
  { name: "麦积山", lat: 34.35, lng: 105.99, province: "甘肃" },
  { name: "鸣沙山月牙泉", lat: 40.09, lng: 94.67, province: "甘肃" },
  { name: "炳灵寺", lat: 35.8, lng: 103.04, province: "甘肃" },
  { name: "官鹅沟", lat: 33.99, lng: 104.35, province: "甘肃" },
  { name: "冶力关", lat: 34.9, lng: 103.7, province: "甘肃" },
  { name: "七彩丹霞", lat: 38.94, lng: 100.13, province: "甘肃" },
  { name: "青海湖", lat: 36.58, lng: 100.51, province: "青海" },
  { name: "阿咪东索", lat: 38.17, lng: 100.28, province: "青海" },
  { name: "塔尔寺", lat: 36.49, lng: 101.57, province: "青海" },
  { name: "互助土族故土园", lat: 36.85, lng: 101.95, province: "青海" },
  { name: "沙湖", lat: 38.8, lng: 106.35, province: "宁夏" },
  { name: "沙坡头", lat: 37.45, lng: 105.0, province: "宁夏" },
  { name: "镇北堡影视城", lat: 38.62, lng: 106.02, province: "宁夏" },
  { name: "水洞沟", lat: 38.3, lng: 106.52, province: "宁夏" },
  { name: "青铜峡黄河大峡谷", lat: 37.9, lng: 106.0, province: "宁夏" },
  { name: "六盘山", lat: 35.35, lng: 106.3, province: "宁夏" },
  { name: "天山天池", lat: 43.88, lng: 88.12, province: "新疆" },
  { name: "葡萄沟", lat: 42.96, lng: 89.21, province: "新疆" },
  { name: "喀纳斯", lat: 48.7, lng: 87.02, province: "新疆" },
  { name: "可可托海", lat: 47.2, lng: 89.78, province: "新疆" },
  { name: "白沙湖", lat: 48.6, lng: 85.58, province: "新疆" },
  { name: "那拉提", lat: 43.3, lng: 84.0, province: "新疆" },
  { name: "喀拉峻", lat: 43.0, lng: 81.7, province: "新疆" },
  { name: "泽普金湖杨", lat: 38.18, lng: 77.27, province: "新疆" },
  { name: "喀什古城", lat: 39.47, lng: 75.99, province: "新疆" },
  { name: "帕米尔", lat: 37.77, lng: 75.22, province: "新疆" },
  { name: "天山大峡谷", lat: 43.45, lng: 87.43, province: "新疆" },
  { name: "博斯腾湖", lat: 42.0, lng: 86.9, province: "新疆" },
  { name: "巴音布鲁克", lat: 43.02, lng: 84.15, province: "新疆" },
  { name: "世界魔鬼城", lat: 46.17, lng: 85.64, province: "新疆" },
  { name: "赛里木湖", lat: 44.6, lng: 81.2, province: "新疆" },
  { name: "塔克拉玛干", lat: 40.54, lng: 81.28, province: "新疆" },
  { name: "托木尔大峡谷", lat: 41.55, lng: 80.42, province: "新疆" },
  { name: "江布拉克", lat: 43.98, lng: 89.8, province: "新疆" },
];
/** 集合已存在时 createCollection 会报错——吞掉，不存在时静默建好，跟 db.ts/handlers 里
 * 「表可能还没建过」的处理方式一致（task-2/3 也是这么建 blockwords/logins/events 的）。 */
async function ensureCollection(db: any, col: string) {
  try {
    await db.createCollection(col);
  } catch {
    // 已存在，忽略
  }
}

/** 通用幂等灌入：按 keyField 去重，已存在（含本次运行中刚插入的）就跳过。*/
async function seedCollection(
  db: any,
  col: string,
  keyField: string,
  items: Array<Record<string, unknown>>,
) {
  await ensureCollection(db, col);
  const existing = await db.collection(col).limit(1000).get();
  const seen = new Set<string>((existing.data ?? []).map((d: any) => d[keyField]));
  let created = 0;
  let skipped = 0;
  for (const item of items) {
    const key = item[keyField] as string;
    if (seen.has(key)) {
      skipped++;
      continue;
    }
    await db.collection(col).add(item);
    seen.add(key);
    created++;
  }
  console.log(`${col}: 新建 ${created} 条，跳过（已存在）${skipped} 条，期望总数 ${items.length}`);
}

async function main() {
  const db = initDb();

  await seedCollection(
    db,
    'preset_wishes',
    'title',
    LIFE_GOALS_50.map((title, i) => ({ title, sort: i + 1, enabled: true })),
  );

  await seedCollection(
    db,
    'preset_steps',
    'title',
    GOAL_STEPS.map(({ title, steps }, i) => ({ title, steps, sort: i + 1, enabled: true })),
  );

  await seedCollection(
    db,
    'poster_task',
    'slogan',
    TASK_SLOGANS.map((slogan, i) => ({ url: '', slogan, sort: i + 1, enabled: true })),
  );

  await seedCollection(
    db,
    'poster_wish',
    'slogan',
    WISH_SLOGANS.map((slogan, i) => ({ url: '', slogan, sort: i + 1, enabled: true })),
  );

  await seedCollection(
    db,
    'poster_done',
    'slogan',
    DONE_SLOGANS.map((slogan, i) => ({ url: '', slogan, sort: i + 1, enabled: true })),
  );

  await seedCollection(
    db,
    'cover_declare',
    'name',
    DECLARE_COVERS.map((name, i) => ({ url: '', name, sort: i + 1, enabled: true })),
  );

  await seedCollection(
    db,
    'cover_done',
    'name',
    DONE_COVERS.map((name, i) => ({ url: '', name, sort: i + 1, enabled: true })),
  );

  await seedCollection(
    db,
    'hero_images',
    'name',
    HERO_IMAGES.map((name, i) => ({ url: '', name, sort: i + 1, enabled: true })),
  );

  await seedCollection(
    db,
    'achv_defs',
    'slug',
    ACHV_DEFS.map((a, i) => ({ ...a, icon: '', sort: i + 1, enabled: true })),
  );

  await seedCollection(
    db,
    'spots',
    'name',
    SPOTS.map((s, i) => ({ ...s, sort: i + 1, enabled: true })),
  );

  console.log('done');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
