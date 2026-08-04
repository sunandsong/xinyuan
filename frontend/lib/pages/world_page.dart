import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../data.dart';
import '../spot_geo.dart';
import '../theme.dart';
import '../ui.dart';

/// 一处地点：中文名用来和心愿里填的「在哪儿完成的」做匹配，英文名印在瓦片上
class _Place {
  const _Place(
    this.cn,
    this.en, [
    this.icon = '',
    this.alias = const <String>[],
  ]);
  final String cn;
  final String en;
  final String icon; // 图标 emoji；景区留空，展示时按名字关键词给默认图标
  final List<String> alias;
}

/// 一个分区；[parent] 表示本区任一处点亮后，上级地点也跟着点亮（省 → 中国 → 亚洲）
class _Section {
  const _Section(this.title, this.parent, this.places);
  final String title;
  final String? parent;
  final List<_Place> places;
}

/// 地点清单：中国（省份）→ 各省 5A 景区 → 全球（大洲/大洋）压轴。
/// 上级传导按分区倒序算：景区分区排在中国区之后，倒序先算景区亮省、再算省亮亚洲
const _sections = <_Section>[
  _Section('中国', '亚洲', [
    _Place('北京', 'BEIJING', '🏯'),
    _Place('上海', 'SHANGHAI', '🌆'),
    _Place('天津', 'TIANJIN', '⚓'),
    _Place('重庆', 'CHONGQING', '🌶️'),
    _Place('河北', 'HEBEI', '🧱'),
    _Place('山西', 'SHANXI', '🏮'),
    _Place('内蒙古', 'NEI MONGOL', '🐎'),
    _Place('辽宁', 'LIAONING', '🏭'),
    _Place('吉林', 'JILIN', '❄️'),
    _Place('黑龙江', 'HEILONGJIANG', '☃️'),
    _Place('江苏', 'JIANGSU', '🌿'),
    _Place('浙江', 'ZHEJIANG', '🍵'),
    _Place('安徽', 'ANHUI', '⛰️'),
    _Place('福建', 'FUJIAN', '🏘️'),
    _Place('江西', 'JIANGXI', '🗻'),
    _Place('山东', 'SHANDONG', '🌅'),
    _Place('河南', 'HENAN', '🐉'),
    _Place('湖北', 'HUBEI', '🌉'),
    _Place('湖南', 'HUNAN', '🏞️'),
    _Place('广东', 'GUANGDONG', '🏙️'),
    _Place('广西', 'GUANGXI', '🛶'),
    _Place('海南', 'HAINAN', '🏝️'),
    _Place('四川', 'SICHUAN', '🐼'),
    _Place('贵州', 'GUIZHOU', '💧'),
    _Place('云南', 'YUNNAN', '🌸'),
    _Place('西藏', 'XIZANG', '🏔️'),
    _Place('陕西', 'SHAANXI', '🗿'),
    _Place('甘肃', 'GANSU', '🐪'),
    _Place('青海', 'QINGHAI', '🦌'),
    _Place('宁夏', 'NINGXIA', '🍇'),
    _Place('新疆', 'XINJIANG', '🏜️'),
    _Place('香港', 'HONG KONG', '🌃'),
    _Place('澳门', 'MACAO', '🎰'),
    _Place('台湾', 'TAIWAN', '🌺'),
  ]),
  // 5A 景区：按省分区，任一景区点亮，所在省份（和亚洲）会跟着亮。
  // 名单按文旅部 5A 名录整理（约 350 家），名字取常用叫法方便和心愿地点匹配
  _Section('北京 · 景区', '北京', [
    _Place('故宫', ''),
    _Place('天坛', ''),
    _Place('颐和园', ''),
    _Place('八达岭长城', '', '', ['八达岭', '慕田峪']),
    _Place('明十三陵', '', '', ['十三陵']),
    _Place('恭王府', ''),
    _Place('奥林匹克公园', '', '', ['鸟巢', '水立方']),
    _Place('圆明园', ''),
    _Place('大运河', '', '', ['通州运河']),
  ]),
  _Section('天津 · 景区', '天津', [
    _Place('古文化街', ''),
    _Place('盘山', ''),
  ]),
  _Section('河北 · 景区', '河北', [
    _Place('山海关', ''),
    _Place('白洋淀', ''),
    _Place('野三坡', ''),
    _Place('白石山', ''),
    _Place('清西陵', ''),
    _Place('避暑山庄', '', '', ['承德']),
    _Place('金山岭长城', '', '', ['金山岭']),
    _Place('西柏坡', ''),
    _Place('清东陵', ''),
    _Place('唐山南湖', '', '', ['开滦']),
    _Place('娲皇宫', ''),
    _Place('广府古城', ''),
    _Place('衡水湖', ''),
  ]),
  _Section('山西 · 景区', '山西', [
    _Place('云冈石窟', '', '', ['云冈']),
    _Place('五台山', ''),
    _Place('皇城相府', ''),
    _Place('绵山', ''),
    _Place('平遥古城', '', '', ['平遥']),
    _Place('雁门关', ''),
    _Place('洪洞大槐树', '', '', ['大槐树']),
    _Place('太行山大峡谷', '', '', ['八泉峡']),
    _Place('云丘山', ''),
    _Place('壶口瀑布', ''),
    _Place('晋祠', '', '', ['天龙山']),
    _Place('乔家大院', ''),
  ]),
  _Section('内蒙古 · 景区', '内蒙古', [
    _Place('响沙湾', ''),
    _Place('成吉思汗陵', ''),
    _Place('满洲里', '', '', ['中俄边境']),
    _Place('阿尔山', '', '', ['柴河']),
    _Place('阿斯哈图石阵', '', '', ['阿斯哈图']),
    _Place('额济纳胡杨林', '', '', ['额济纳', '胡杨林']),
    _Place('呼伦贝尔大草原', '', '', ['呼伦贝尔', '莫尔格勒河']),
    _Place('老牛湾', ''),
  ]),
  _Section('辽宁 · 景区', '辽宁', [
    _Place('沈阳植物园', ''),
    _Place('老虎滩', ''),
    _Place('金石滩', ''),
    _Place('本溪水洞', ''),
    _Place('千山', ''),
    _Place('红海滩', '', '', ['盘锦']),
    _Place('五女山', ''),
  ]),
  _Section('吉林 · 景区', '吉林', [
    _Place('伪满皇宫', ''),
    _Place('长白山', ''),
    _Place('净月潭', ''),
    _Place('长影世纪城', ''),
    _Place('六鼎山', ''),
    _Place('长春雕塑公园', '', '', ['世界雕塑公园']),
    _Place('高句丽', '', '', ['集安']),
    _Place('查干湖', ''),
    _Place('嫩江湾', ''),
  ]),
  _Section('黑龙江 · 景区', '黑龙江', [
    _Place('太阳岛', ''),
    _Place('五大连池', ''),
    _Place('镜泊湖', ''),
    _Place('汤旺河', '', '', ['林海奇石']),
    _Place('北极村', '', '', ['漠河']),
    _Place('虎头', '', '', ['珍宝岛']),
    _Place('扎龙', '', '', ['扎龙湿地']),
  ]),
  _Section('上海 · 景区', '上海', [
    _Place('东方明珠', ''),
    _Place('上海野生动物园', '', '', ['野生动物园']),
    _Place('上海科技馆', '', '', ['科技馆']),
    _Place('一大会址', '', '', ['中共一大']),
    _Place('明珠湖', '', '', ['西沙湿地']),
  ]),
  _Section('江苏 · 景区', '江苏', [
    _Place('中山陵', '', '', ['钟山']),
    _Place('无锡影视基地', '', '', ['三国城', '水浒城']),
    _Place('苏州园林', '', '', ['拙政园', '虎丘', '留园']),
    _Place('周庄', ''),
    _Place('灵山大佛', '', '', ['灵山']),
    _Place('瘦西湖', ''),
    _Place('同里', ''),
    _Place('金鸡湖', ''),
    _Place('太湖', '', '', ['吴中']),
    _Place('沙家浜', '', '', ['虞山', '尚湖']),
    _Place('中华恐龙园', '', '', ['恐龙城', '恐龙园']),
    _Place('天目湖', ''),
    _Place('淹城', '', '', ['春秋淹城']),
    _Place('濠河', ''),
    _Place('溱湖', ''),
    _Place('周恩来故里', '', '', ['周恩来纪念馆']),
    _Place('大丰麋鹿园', '', '', ['麋鹿']),
    _Place('云龙湖', ''),
    _Place('花果山', ''),
    _Place('连岛', ''),
    _Place('洪泽湖湿地', '', '', ['洪泽湖']),
    _Place('惠山古镇', '', '', ['惠山']),
  ]),
  _Section('浙江 · 景区', '浙江', [
    _Place('西湖', ''),
    _Place('西溪湿地', '', '', ['西溪']),
    _Place('千岛湖', ''),
    _Place('雁荡山', ''),
    _Place('普陀山', ''),
    _Place('乌镇', ''),
    _Place('嘉兴南湖', '', '', ['南湖']),
    _Place('西塘', ''),
    _Place('溪口', '', '', ['滕头', '雪窦山']),
    _Place('天一阁', '', '', ['月湖']),
    _Place('鲁迅故里', '', '', ['沈园']),
    _Place('横店影视城', '', '', ['横店']),
    _Place('金华双龙洞', '', '', ['双龙洞']),
    _Place('根宫佛国', '', '', ['开化']),
    _Place('江郎山', '', '', ['廿八都']),
    _Place('南浔', ''),
    _Place('天台山', ''),
    _Place('神仙居', ''),
    _Place('刘伯温故里', '', '', ['文成']),
    _Place('仙都', '', '', ['缙云']),
    _Place('云和梯田', ''),
  ]),
  _Section('安徽 · 景区', '安徽', [
    _Place('黄山', ''),
    _Place('宏村', '', '', ['西递']),
    _Place('古徽州', '', '', ['徽州古城', '呈坎', '唐模']),
    _Place('九华山', ''),
    _Place('天柱山', ''),
    _Place('万佛湖', ''),
    _Place('龙川', ''),
    _Place('八里河', ''),
    _Place('三河古镇', ''),
    _Place('芜湖方特', '', '', ['方特']),
    _Place('采石矶', ''),
    _Place('琅琊山', ''),
  ]),
  _Section('福建 · 景区', '福建', [
    _Place('鼓浪屿', ''),
    _Place('武夷山', ''),
    _Place('永定土楼', '', '', ['土楼']),
    _Place('古田会议旧址', '', '', ['古田']),
    _Place('泰宁', '', '', ['大金湖']),
    _Place('清源山', ''),
    _Place('白水洋', '', '', ['鸳鸯溪']),
    _Place('太姥山', ''),
    _Place('三坊七巷', ''),
    _Place('厦门植物园', '', '', ['万石植物园']),
    _Place('湄洲岛', '', '', ['妈祖']),
    _Place('冠豸山', ''),
  ]),
  _Section('江西 · 景区', '江西', [
    _Place('庐山', ''),
    _Place('庐山西海', ''),
    _Place('井冈山', ''),
    _Place('三清山', ''),
    _Place('婺源', '', '', ['江湾']),
    _Place('篁岭', ''),
    _Place('龟峰', ''),
    _Place('龙虎山', ''),
    _Place('景德镇古窑', '', '', ['古窑']),
    _Place('滕王阁', ''),
    _Place('武功山', ''),
    _Place('瑞金', '', '', ['共和国摇篮']),
    _Place('三百山', ''),
    _Place('明月山', ''),
    _Place('大觉山', ''),
  ]),
  _Section('山东 · 景区', '山东', [
    _Place('蓬莱阁', ''),
    _Place('龙口南山', '', '', ['南山大佛']),
    _Place('三孔', '', '', ['曲阜', '孔庙', '孔府']),
    _Place('微山湖', ''),
    _Place('泰山', ''),
    _Place('崂山', ''),
    _Place('青岛奥帆', '', '', ['奥帆']),
    _Place('刘公岛', ''),
    _Place('华夏城', ''),
    _Place('台儿庄古城', '', '', ['台儿庄']),
    _Place('趵突泉', '', '', ['大明湖', '天下第一泉']),
    _Place('沂蒙山', ''),
    _Place('地下大峡谷', '', '', ['萤火虫水洞']),
    _Place('青州古城', '', '', ['青州']),
    _Place('黄河口', ''),
    _Place('周村古商城', '', '', ['周村']),
  ]),
  _Section('河南 · 景区', '河南', [
    _Place('少林寺', '', '', ['嵩山']),
    _Place('龙门石窟', '', '', ['龙门']),
    _Place('白云山', ''),
    _Place('老君山', '', '', ['鸡冠洞']),
    _Place('龙潭大峡谷', ''),
    _Place('云台山', '', '', ['神农山', '青天河']),
    _Place('清明上河园', ''),
    _Place('殷墟', ''),
    _Place('红旗渠', '', '', ['太行大峡谷']),
    _Place('尧山', '', '', ['中原大佛']),
    _Place('老界岭', '', '', ['恐龙遗址园']),
    _Place('嵖岈山', ''),
    _Place('芒砀山', ''),
    _Place('八里沟', ''),
    _Place('宝泉', ''),
    _Place('鸡公山', ''),
    _Place('太昊陵', '', '', ['伏羲陵']),
  ]),
  _Section('湖北 · 景区', '湖北', [
    _Place('黄鹤楼', ''),
    _Place('东湖', ''),
    _Place('木兰天池', '', '', ['木兰山', '木兰草原']),
    _Place('三峡大坝', '', '', ['屈原故里']),
    _Place('三峡人家', ''),
    _Place('三峡大瀑布', ''),
    _Place('清江画廊', '', '', ['长阳']),
    _Place('武当山', ''),
    _Place('神农溪', ''),
    _Place('恩施大峡谷', ''),
    _Place('腾龙洞', ''),
    _Place('神农架', ''),
    _Place('赤壁古战场', '', '', ['赤壁']),
    _Place('古隆中', '', '', ['隆中']),
    _Place('明显陵', ''),
    _Place('龟峰山', ''),
  ]),
  _Section('湖南 · 景区', '湖南', [
    _Place('衡山', '', '', ['南岳']),
    _Place('武陵源', '', '', ['张家界', '天门山']),
    _Place('岳麓山', '', '', ['橘子洲']),
    _Place('花明楼', ''),
    _Place('岳阳楼', '', '', ['君山岛']),
    _Place('韶山', ''),
    _Place('东江湖', ''),
    _Place('崀山', ''),
    _Place('炎帝陵', ''),
    _Place('桃花源', ''),
    _Place('矮寨', '', '', ['十八洞', '德夯']),
    _Place('凤凰古城', '', '', ['凤凰']),
  ]),
  _Section('广东 · 景区', '广东', [
    _Place('长隆', ''),
    _Place('广州白云山', ''),
    _Place('华侨城', '', '', ['世界之窗', '欢乐谷']),
    _Place('观澜湖', ''),
    _Place('西樵山', ''),
    _Place('长鹿', '', '', ['长鹿农庄']),
    _Place('丹霞山', ''),
    _Place('雁南飞', '', '', ['雁南飞茶田']),
    _Place('罗浮山', ''),
    _Place('惠州西湖', ''),
    _Place('孙中山故里', '', '', ['中山故里']),
    _Place('开平碉楼', '', '', ['开平']),
    _Place('海陵岛', '', '', ['大角湾']),
    _Place('肇庆星湖', '', '', ['七星岩', '鼎湖山']),
    _Place('连州地下河', '', '', ['连州']),
    _Place('万绿湖', ''),
  ]),
  _Section('广西 · 景区', '广西', [
    _Place('漓江', '', '', ['阳朔']),
    _Place('乐满地', ''),
    _Place('独秀峰', '', '', ['王城']),
    _Place('两江四湖', '', '', ['象鼻山', '象山景区']),
    _Place('德天瀑布', '', '', ['德天']),
    _Place('花山岩画', '', '', ['花山']),
    _Place('百色起义纪念园', '', '', ['百色']),
    _Place('青秀山', ''),
    _Place('涠洲岛', '', '', ['鳄鱼山']),
    _Place('黄姚古镇', '', '', ['黄姚']),
    _Place('程阳八寨', '', '', ['程阳']),
  ]),
  _Section('海南 · 景区', '海南', [
    _Place('三亚南山', '', '', ['南山寺', '南山文化']),
    _Place('大小洞天', ''),
    _Place('蜈支洲岛', '', '', ['蜈支洲']),
    _Place('天涯海角', ''),
    _Place('分界洲岛', '', '', ['分界洲']),
    _Place('呀诺达', ''),
    _Place('槟榔谷', ''),
  ]),
  _Section('重庆 · 景区', '重庆', [
    _Place('大足石刻', '', '', ['大足']),
    _Place('小三峡', ''),
    _Place('武隆喀斯特', '', '', ['武隆', '天生三桥', '仙女山']),
    _Place('金佛山', ''),
    _Place('酉阳桃花源', ''),
    _Place('黑山谷', ''),
    _Place('四面山', ''),
    _Place('云阳龙缸', '', '', ['龙缸']),
    _Place('阿依河', ''),
    _Place('濯水古镇', '', '', ['濯水']),
    _Place('白帝城', '', '', ['瞿塘峡']),
    _Place('武陵山大裂谷', ''),
  ]),
  _Section('四川 · 景区', '四川', [
    _Place('都江堰', '', '', ['青城山']),
    _Place('峨眉山', ''),
    _Place('乐山大佛', '', '', ['乐山']),
    _Place('九寨沟', ''),
    _Place('黄龙', ''),
    _Place('汶川', '', '', ['映秀']),
    _Place('四姑娘山', ''),
    _Place('阆中古城', '', '', ['阆中']),
    _Place('朱德故里', ''),
    _Place('北川羌城', '', '', ['北川']),
    _Place('邓小平故里', ''),
    _Place('剑门关', '', '', ['剑门蜀道', '翠云廊']),
    _Place('海螺沟', ''),
    _Place('稻城亚丁', '', '', ['亚丁']),
    _Place('碧峰峡', ''),
    _Place('光雾山', ''),
    _Place('安仁古镇', '', '', ['安仁']),
    _Place('天台山', ''),
  ]),
  _Section('贵州 · 景区', '贵州', [
    _Place('黄果树', '', '', ['黄果树瀑布']),
    _Place('龙宫', ''),
    _Place('百里杜鹃', ''),
    _Place('织金洞', ''),
    _Place('荔波樟江', '', '', ['荔波', '小七孔']),
    _Place('青岩古镇', '', '', ['青岩']),
    _Place('梵净山', ''),
    _Place('镇远古城', '', '', ['镇远']),
    _Place('赤水丹霞', '', '', ['赤水']),
    _Place('万峰林', ''),
  ]),
  _Section('云南 · 景区', '云南', [
    _Place('石林', ''),
    _Place('昆明世博园', '', '', ['世博园']),
    _Place('玉龙雪山', '', '', ['玉龙']),
    _Place('丽江古城', '', '', ['丽江']),
    _Place('崇圣寺三塔', '', '', ['大理三塔', '崇圣寺']),
    _Place('西双版纳植物园', '', '', ['勐仑']),
    _Place('普达措', '', '', ['香格里拉']),
    _Place('腾冲热海', '', '', ['火山热海', '腾冲火山']),
    _Place('和顺古镇', '', '', ['和顺']),
    _Place('普者黑', ''),
  ]),
  _Section('西藏 · 景区', '西藏', [
    _Place('布达拉宫', ''),
    _Place('大昭寺', ''),
    _Place('巴松措', ''),
    _Place('雅鲁藏布大峡谷', '', '', ['雅鲁藏布']),
    _Place('扎什伦布寺', '', '', ['扎什伦布']),
  ]),
  _Section('陕西 · 景区', '陕西', [
    _Place('兵马俑', '', '', ['秦始皇陵']),
    _Place('华清池', '', '', ['华清宫']),
    _Place('大雁塔', '', '', ['大唐芙蓉园']),
    _Place('西安城墙', '', '', ['碑林']),
    _Place('大明宫', ''),
    _Place('黄帝陵', ''),
    _Place('延安革命纪念地', '', '', ['枣园', '杨家岭']),
    _Place('壶口瀑布', ''),
    _Place('乾坤湾', ''),
    _Place('华山', ''),
    _Place('法门寺', ''),
    _Place('太白山', ''),
    _Place('金丝峡', ''),
    _Place('乾陵', ''),
  ]),
  _Section('甘肃 · 景区', '甘肃', [
    _Place('嘉峪关', ''),
    _Place('崆峒山', ''),
    _Place('麦积山', ''),
    _Place('鸣沙山月牙泉', '', '', ['鸣沙山', '月牙泉']),
    _Place('炳灵寺', ''),
    _Place('官鹅沟', ''),
    _Place('冶力关', ''),
    _Place('七彩丹霞', '', '', ['张掖丹霞']),
  ]),
  _Section('青海 · 景区', '青海', [
    _Place('青海湖', ''),
    _Place('阿咪东索', ''),
    _Place('塔尔寺', ''),
    _Place('互助土族故土园', '', '', ['互助']),
  ]),
  _Section('宁夏 · 景区', '宁夏', [
    _Place('沙湖', ''),
    _Place('沙坡头', ''),
    _Place('镇北堡影视城', '', '', ['镇北堡', '西部影城']),
    _Place('水洞沟', ''),
    _Place('青铜峡黄河大峡谷', '', '', ['青铜峡']),
    _Place('六盘山', ''),
  ]),
  _Section('新疆 · 景区', '新疆', [
    _Place('天山天池', '', '', ['天池']),
    _Place('葡萄沟', ''),
    _Place('喀纳斯', ''),
    _Place('可可托海', ''),
    _Place('白沙湖', ''),
    _Place('那拉提', ''),
    _Place('喀拉峻', ''),
    _Place('泽普金湖杨', '', '', ['金湖杨']),
    _Place('喀什古城', '', '', ['喀什噶尔']),
    _Place('帕米尔', '', '', ['塔县']),
    _Place('天山大峡谷', ''),
    _Place('博斯腾湖', ''),
    _Place('巴音布鲁克', ''),
    _Place('世界魔鬼城', '', '', ['魔鬼城', '乌尔禾']),
    _Place('赛里木湖', ''),
    _Place('塔克拉玛干', '', '', ['三五九旅']),
    _Place('托木尔大峡谷', '', '', ['托木尔']),
    _Place('江布拉克', ''),
  ]),
  _Section('全球', null, [
    _Place('亚洲', 'ASIA', '🌏'),
    _Place('欧洲', 'EUROPE', '🏰'),
    _Place('非洲', 'AFRICA', '🦁'),
    _Place('北美洲', 'N. AMERICA', '🗽'),
    _Place('南美洲', 'S. AMERICA', '🦜'),
    _Place('大洋洲', 'OCEANIA', '🦘'),
    _Place('南极洲', 'ANTARCTICA', '🐧'),
    _Place('太平洋', 'PACIFIC', '🐋'),
    _Place('大西洋', 'ATLANTIC', '🌊'),
    _Place('印度洋', 'INDIAN', '⛵'),
    _Place('北冰洋', 'ARCTIC', '🐻‍❄️'),
  ]),
];

/// 地点名 → 最早点亮时间；不在表里 = 未点亮。
/// 数据来自已完成心愿填的「在哪儿完成的」，按名字/别名做包含匹配
Map<String, DateTime> _litMap() {
  final res = <String, DateTime>{};
  void mark(String name, DateTime at) {
    final cur = res[name];
    if (cur == null || at.isBefore(cur)) res[name] = at;
  }

  for (final w in AppData.I.wishes) {
    final loc = w.location;
    if (!w.done || loc == null || loc.isEmpty) continue;
    final at = w.doneAt ?? w.updatedAt;
    final hits = <String>[];
    for (final s in _sections) {
      for (final p in s.places) {
        if (loc.contains(p.cn) || p.alias.any(loc.contains)) hits.add(p.cn);
      }
    }
    // 丢掉被更长地名包住的误命中：填「南苏丹」不该把「苏丹」也点亮
    for (final n in hits) {
      if (hits.any((o) => o != n && o.contains(n))) continue;
      mark(n, at);
    }
  }
  // 定位打卡点亮的景区（和心愿地点点亮的合并，取更早的时间）
  AppData.I.checkins.forEach(
    (name, ms) => mark(name, DateTime.fromMillisecondsSinceEpoch(ms)),
  );
  // 子区点亮 → 上级点亮；倒序遍历让 景区 → 省 → 亚洲 这条链能一路传上去
  // （景区分区排在最后，先算它们才能把省份亮起来，再轮到中国区把亚洲亮起来）
  for (final s in _sections.reversed) {
    final parent = s.parent;
    if (parent == null) continue;
    DateTime? first;
    for (final p in s.places) {
      final at = res[p.cn];
      if (at != null && (first == null || at.isBefore(first))) first = at;
    }
    if (first != null) mark(parent, first);
  }
  return res;
}

/// 已点亮的地点总数（「我的」页显示用）
int litPlaceCount() => _litMap().length;

/// 名字散列出一个稳定的色调，同一个地方永远同一个颜色
int _hash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

const _tints = [
  Color(0xFF3D7EB8),
  Color(0xFF8A4E6E),
  Color(0xFFC98B3D),
  Color(0xFF4F8C6B),
  Color(0xFF6A5AA8),
  Color(0xFF2F8C9E),
  Color(0xFFB05A4E),
  Color(0xFF5E7BC4),
];

/// 点亮世界：去过的地方按分区点亮，来源是已完成心愿填的地点
class WorldPage extends StatelessWidget {
  const WorldPage({super.key});

  static const _bg = Color(0xFF1E2340);
  static const _ink = Color(0xFFE8EEF8);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppData.I,
      builder: (context, _) {
        final lit = _litMap();
        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      DarkPill(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            '点 亮 世 界',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 4,
                              color: _ink,
                            ),
                          ),
                        ),
                      ),
                      // 定位打卡：在景区附近就能直接点亮它
                      DarkPill(
                        icon: Icons.my_location_rounded,
                        onTap: () => _checkIn(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  // 两百多块瓦片：用 Sliver 让网格随滚动懒加载，别一次全建出来
                  child: CustomScrollView(
                    slivers: [
                      for (final s in _sections) ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          sliver: SliverToBoxAdapter(
                            child: _sectionTitle(s, lit),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: .66,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _tile(s.places[i], lit[s.places[i].cn]),
                              childCount: s.places.length,
                            ),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// 定位打卡：取一次当前位置 → 只有离得最近且 10km 内的那个景区能点亮
  Future<void> _checkIn(BuildContext context) async {
    if (!AppData.I.signedIn) {
      _toast(context, '登录后才能定位打卡');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (context.mounted) _toast(context, '需要定位权限才能打卡，请在系统设置里允许');
      return;
    }
    late final Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      if (context.mounted) _toast(context, '定位失败，稍后再试');
      return;
    }
    if (!context.mounted) return;
    // 只认离得最近的那一个景区，而且必须在 10 公里内：
    // 站在故宫不能顺手把颐和园、十三陵也点了
    final near = nearbySpots(pos.latitude, pos.longitude, maxKm: 10, limit: 1);
    if (near.isEmpty) {
      _toast(context, '附近没有 5A 景区，走进景区（10 公里内）再打卡');
      return;
    }
    final (name, km) = near.first;
    if (AppData.I.checkins.containsKey(name)) {
      _toast(context, '「$name」已经点亮过了');
      return;
    }
    await showAppSheet(
      context,
      Builder(builder: (sheetCtx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('你在「$name」附近',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(km < 1 ? '就在这儿' : '距离约 ${km.toStringAsFixed(1)} 公里',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: T.muted)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: T.accent,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                AppData.I.checkIn(name);
                Navigator.pop(sheetCtx);
                _toast(context, '已点亮 $name ✨');
              },
              child: const Text('点亮它',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            const Text('不是这儿？走近你想打卡的景区再试',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: T.muted)),
          ],
        );
      }),
    );
  }

  Widget _sectionTitle(_Section s, Map<String, DateTime> lit) {
    final on = s.places.where((p) => lit.containsKey(p.cn)).length;
    return Text(
      '${s.title}（已点亮 $on/${s.places.length}）',
      style: const TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w600,
        color: _ink,
      ),
    );
  }

  /// 景区没配 emoji，按名字关键词给个默认图标
  static String _spotIcon(String n) {
    if (n.contains('瀑')) return '💦';
    if (n.contains('窟')) return '🛕';
    if (n.contains('洞')) return '🕳️';
    if (n.contains('山') || n.contains('峰') || n.contains('岭')) return '⛰️';
    if (n.contains('湖') || n.contains('河') || n.contains('江') ||
        n.contains('溪') || n.contains('泉') || n.contains('湿地')) {
      return '🌊';
    }
    if (n.contains('岛') || n.contains('湾')) return '🏝️';
    if (n.contains('寺') || n.contains('佛') || n.contains('塔') ||
        n.contains('措')) {
      return '🛕';
    }
    if (n.contains('宫') || n.contains('陵') || n.contains('楼') ||
        n.contains('城') || n.contains('镇') || n.contains('街') ||
        n.contains('坛') || n.contains('府') || n.contains('故里') ||
        n.contains('关')) {
      return '🏯';
    }
    if (n.contains('园')) return '🌳';
    if (n.contains('峡') || n.contains('沟') || n.contains('林')) return '🌲';
    return '📍';
  }

  Widget _tile(_Place p, DateTime? at) {
    final on = at != null;
    final icon = p.icon.isEmpty ? _spotIcon(p.cn) : p.icon;
    final base = _tints[_hash(p.cn) % _tints.length];
    // 点亮=本色渐变，未点亮=褪成暗蓝灰
    final c1 = on
        ? Color.lerp(base, Colors.white, .18)!
        : Color.lerp(base, const Color(0xFF2A2F4A), .82)!;
    final c2 = on
        ? Color.lerp(base, Colors.black, .35)!
        : Color.lerp(base, const Color(0xFF1B2038), .88)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c1, c2],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: on ? 1 : .28,
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 27),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            p.en,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .3,
                              color: Colors.white.withValues(
                                alpha: on ? .9 : .32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (on)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.black.withValues(alpha: .55),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        ymdDots(at),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Flexible(
          child: Text(
            p.cn,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: _ink.withValues(alpha: on ? .95 : .4),
            ),
          ),
        ),
      ],
    );
  }
}
