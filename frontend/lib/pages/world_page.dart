import 'package:flutter/material.dart';
import '../data.dart';
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
  final String icon; // 图标：国家=国旗 emoji，大洲/省份=主题 emoji（系统字体自带）
  final List<String> alias;
}

/// 一个分区；[parent] 表示本区任一处点亮后，上级地点也跟着点亮（省 → 中国 → 亚洲）
class _Section {
  const _Section(this.title, this.parent, this.places);
  final String title;
  final String? parent;
  final List<_Place> places;
}

/// 地点清单。顺序有意义：中国区排在亚洲区之前，点亮才能一级级传上去
const _sections = <_Section>[
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
  _Section('中国', '中国', [
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
  _Section('亚洲', '亚洲', [
    _Place('中国', 'CHINA', '🇨🇳'),
    _Place('日本', 'JAPAN', '🇯🇵', ['东京', '北海道', '冲绳', '大阪', '京都']),
    _Place('韩国', 'KOREA', '🇰🇷', ['首尔', '济州']),
    _Place('朝鲜', 'DPRK', '🇰🇵'),
    _Place('蒙古', 'MONGOLIA', '🇲🇳'),
    _Place('越南', 'VIETNAM', '🇻🇳', ['河内', '岘港']),
    _Place('老挝', 'LAOS', '🇱🇦'),
    _Place('柬埔寨', 'CAMBODIA', '🇰🇭', ['吴哥']),
    _Place('泰国', 'THAILAND', '🇹🇭', ['曼谷', '清迈', '普吉', '涛岛']),
    _Place('缅甸', 'MYANMAR', '🇲🇲'),
    _Place('马来西亚', 'MALAYSIA', '🇲🇾', ['吉隆坡', '沙巴']),
    _Place('新加坡', 'SINGAPORE', '🇸🇬'),
    _Place('印度尼西亚', 'INDONESIA', '🇮🇩', ['巴厘岛', '雅加达']),
    _Place('菲律宾', 'PHILIPPINES', '🇵🇭', ['长滩岛', '宿务']),
    _Place('文莱', 'BRUNEI', '🇧🇳'),
    _Place('东帝汶', 'TIMOR-LESTE', '🇹🇱'),
    _Place('印度', 'INDIA', '🇮🇳'),
    _Place('巴基斯坦', 'PAKISTAN', '🇵🇰'),
    _Place('孟加拉国', 'BANGLADESH', '🇧🇩'),
    _Place('尼泊尔', 'NEPAL', '🇳🇵', ['加德满都']),
    _Place('不丹', 'BHUTAN', '🇧🇹'),
    _Place('斯里兰卡', 'SRI LANKA', '🇱🇰'),
    _Place('马尔代夫', 'MALDIVES', '🇲🇻'),
    _Place('阿富汗', 'AFGHANISTAN', '🇦🇫'),
    _Place('哈萨克斯坦', 'KAZAKHSTAN', '🇰🇿'),
    _Place('乌兹别克斯坦', 'UZBEKISTAN', '🇺🇿'),
    _Place('吉尔吉斯斯坦', 'KYRGYZSTAN', '🇰🇬'),
    _Place('塔吉克斯坦', 'TAJIKISTAN', '🇹🇯'),
    _Place('土库曼斯坦', 'TURKMENISTAN', '🇹🇲'),
    _Place('伊朗', 'IRAN', '🇮🇷'),
    _Place('伊拉克', 'IRAQ', '🇮🇶'),
    _Place('叙利亚', 'SYRIA', '🇸🇾'),
    _Place('黎巴嫩', 'LEBANON', '🇱🇧'),
    _Place('以色列', 'ISRAEL', '🇮🇱', ['耶路撒冷']),
    _Place('巴勒斯坦', 'PALESTINE', '🇵🇸'),
    _Place('约旦', 'JORDAN', '🇯🇴'),
    _Place('沙特阿拉伯', 'SAUDI ARABIA', '🇸🇦'),
    _Place('也门', 'YEMEN', '🇾🇪'),
    _Place('阿曼', 'OMAN', '🇴🇲'),
    _Place('阿联酋', 'UAE', '🇦🇪', ['迪拜', '阿布扎比', '阿拉伯联合酋长国']),
    _Place('卡塔尔', 'QATAR', '🇶🇦'),
    _Place('巴林', 'BAHRAIN', '🇧🇭'),
    _Place('科威特', 'KUWAIT', '🇰🇼'),
    _Place('土耳其', 'TURKEY', '🇹🇷', ['伊斯坦布尔']),
    _Place('塞浦路斯', 'CYPRUS', '🇨🇾'),
    _Place('格鲁吉亚', 'GEORGIA', '🇬🇪'),
    _Place('亚美尼亚', 'ARMENIA', '🇦🇲'),
    _Place('阿塞拜疆', 'AZERBAIJAN', '🇦🇿'),
  ]),
  _Section('欧洲', '欧洲', [
    _Place('英国', 'UK', '🇬🇧', ['伦敦', '苏格兰', '爱丁堡']),
    _Place('爱尔兰', 'IRELAND', '🇮🇪'),
    _Place('法国', 'FRANCE', '🇫🇷', ['巴黎', '普罗旺斯', '尼斯']),
    _Place('德国', 'GERMANY', '🇩🇪', ['柏林', '慕尼黑']),
    _Place('意大利', 'ITALY', '🇮🇹', ['罗马', '威尼斯', '佛罗伦萨', '米兰']),
    _Place('西班牙', 'SPAIN', '🇪🇸', ['巴塞罗那', '马德里']),
    _Place('葡萄牙', 'PORTUGAL', '🇵🇹', ['里斯本']),
    _Place('荷兰', 'NETHERLANDS', '🇳🇱', ['阿姆斯特丹']),
    _Place('比利时', 'BELGIUM', '🇧🇪'),
    _Place('卢森堡', 'LUXEMBOURG', '🇱🇺'),
    _Place('瑞士', 'SWITZERLAND', '🇨🇭', ['因特拉肯', '少女峰']),
    _Place('奥地利', 'AUSTRIA', '🇦🇹', ['维也纳', '哈尔施塔特']),
    _Place('列支敦士登', 'LIECHTENSTEIN', '🇱🇮'),
    _Place('摩纳哥', 'MONACO', '🇲🇨'),
    _Place('安道尔', 'ANDORRA', '🇦🇩'),
    _Place('圣马力诺', 'SAN MARINO', '🇸🇲'),
    _Place('梵蒂冈', 'VATICAN', '🇻🇦'),
    _Place('马耳他', 'MALTA', '🇲🇹'),
    _Place('希腊', 'GREECE', '🇬🇷', ['圣托里尼', '雅典', '米科诺斯']),
    _Place('挪威', 'NORWAY', '🇳🇴', ['卑尔根', '特罗姆瑟']),
    _Place('瑞典', 'SWEDEN', '🇸🇪', ['斯德哥尔摩']),
    _Place('芬兰', 'FINLAND', '🇫🇮', ['赫尔辛基', '罗瓦涅米']),
    _Place('丹麦', 'DENMARK', '🇩🇰', ['哥本哈根']),
    _Place('冰岛', 'ICELAND', '🇮🇸', ['雷克雅未克']),
    _Place('爱沙尼亚', 'ESTONIA', '🇪🇪'),
    _Place('拉脱维亚', 'LATVIA', '🇱🇻'),
    _Place('立陶宛', 'LITHUANIA', '🇱🇹'),
    _Place('波兰', 'POLAND', '🇵🇱'),
    _Place('捷克', 'CZECHIA', '🇨🇿', ['布拉格']),
    _Place('斯洛伐克', 'SLOVAKIA', '🇸🇰'),
    _Place('匈牙利', 'HUNGARY', '🇭🇺', ['布达佩斯']),
    _Place('罗马尼亚', 'ROMANIA', '🇷🇴'),
    _Place('保加利亚', 'BULGARIA', '🇧🇬'),
    _Place('斯洛文尼亚', 'SLOVENIA', '🇸🇮'),
    _Place('克罗地亚', 'CROATIA', '🇭🇷', ['杜布罗夫尼克']),
    _Place('波黑', 'BOSNIA', '🇧🇦'),
    _Place('塞尔维亚', 'SERBIA', '🇷🇸'),
    _Place('黑山', 'MONTENEGRO', '🇲🇪'),
    _Place('北马其顿', 'N. MACEDONIA', '🇲🇰'),
    _Place('阿尔巴尼亚', 'ALBANIA', '🇦🇱'),
    _Place('俄罗斯', 'RUSSIA', '🇷🇺', ['莫斯科', '圣彼得堡', '贝加尔']),
    _Place('乌克兰', 'UKRAINE', '🇺🇦'),
    _Place('白俄罗斯', 'BELARUS', '🇧🇾'),
    _Place('摩尔多瓦', 'MOLDOVA', '🇲🇩'),
  ]),
  _Section('非洲', '非洲', [
    _Place('埃及', 'EGYPT', '🇪🇬', ['开罗', '金字塔']),
    _Place('利比亚', 'LIBYA', '🇱🇾'),
    _Place('突尼斯', 'TUNISIA', '🇹🇳'),
    _Place('阿尔及利亚', 'ALGERIA', '🇩🇿'),
    _Place('摩洛哥', 'MOROCCO', '🇲🇦', ['马拉喀什', '撒哈拉']),
    _Place('苏丹', 'SUDAN', '🇸🇩'),
    _Place('南苏丹', 'S. SUDAN', '🇸🇸'),
    _Place('埃塞俄比亚', 'ETHIOPIA', '🇪🇹'),
    _Place('厄立特里亚', 'ERITREA', '🇪🇷'),
    _Place('吉布提', 'DJIBOUTI', '🇩🇯'),
    _Place('索马里', 'SOMALIA', '🇸🇴'),
    _Place('肯尼亚', 'KENYA', '🇰🇪', ['马赛马拉', '内罗毕']),
    _Place('乌干达', 'UGANDA', '🇺🇬'),
    _Place('坦桑尼亚', 'TANZANIA', '🇹🇿', ['乞力马扎罗', '桑给巴尔']),
    _Place('卢旺达', 'RWANDA', '🇷🇼'),
    _Place('布隆迪', 'BURUNDI', '🇧🇮'),
    _Place('刚果金', 'DR CONGO', '🇨🇩'),
    _Place('刚果布', 'CONGO', '🇨🇬'),
    _Place('中非', 'C. AFRICAN REP.', '🇨🇫'),
    _Place('喀麦隆', 'CAMEROON', '🇨🇲'),
    _Place('乍得', 'CHAD', '🇹🇩'),
    _Place('尼日尔', 'NIGER', '🇳🇪'),
    _Place('尼日利亚', 'NIGERIA', '🇳🇬'),
    _Place('贝宁', 'BENIN', '🇧🇯'),
    _Place('多哥', 'TOGO', '🇹🇬'),
    _Place('加纳', 'GHANA', '🇬🇭'),
    _Place('科特迪瓦', 'COTE DIVOIRE', '🇨🇮'),
    _Place('利比里亚', 'LIBERIA', '🇱🇷'),
    _Place('塞拉利昂', 'SIERRA LEONE', '🇸🇱'),
    _Place('几内亚', 'GUINEA', '🇬🇳'),
    _Place('几内亚比绍', 'GUINEA-BISSAU', '🇬🇼'),
    _Place('塞内加尔', 'SENEGAL', '🇸🇳'),
    _Place('冈比亚', 'GAMBIA', '🇬🇲'),
    _Place('马里', 'MALI', '🇲🇱'),
    _Place('布基纳法索', 'BURKINA FASO', '🇧🇫'),
    _Place('毛里塔尼亚', 'MAURITANIA', '🇲🇷'),
    _Place('佛得角', 'CABO VERDE', '🇨🇻'),
    _Place('圣多美和普林西比', 'SAO TOME', '🇸🇹'),
    _Place('赤道几内亚', 'EQ. GUINEA', '🇬🇶'),
    _Place('加蓬', 'GABON', '🇬🇦'),
    _Place('安哥拉', 'ANGOLA', '🇦🇴'),
    _Place('赞比亚', 'ZAMBIA', '🇿🇲'),
    _Place('马拉维', 'MALAWI', '🇲🇼'),
    _Place('莫桑比克', 'MOZAMBIQUE', '🇲🇿'),
    _Place('津巴布韦', 'ZIMBABWE', '🇿🇼', ['维多利亚瀑布']),
    _Place('博茨瓦纳', 'BOTSWANA', '🇧🇼'),
    _Place('纳米比亚', 'NAMIBIA', '🇳🇦'),
    _Place('南非', 'SOUTH AFRICA', '🇿🇦', ['开普敦', '好望角']),
    _Place('莱索托', 'LESOTHO', '🇱🇸'),
    _Place('斯威士兰', 'ESWATINI', '🇸🇿'),
    _Place('马达加斯加', 'MADAGASCAR', '🇲🇬'),
    _Place('毛里求斯', 'MAURITIUS', '🇲🇺'),
    _Place('塞舌尔', 'SEYCHELLES', '🇸🇨'),
    _Place('科摩罗', 'COMOROS', '🇰🇲'),
  ]),
  _Section('北美洲', '北美洲', [
    _Place('美国', 'USA', '🇺🇸', [
      '纽约',
      '洛杉矶',
      '旧金山',
      '夏威夷',
      '拉斯维加斯',
      '西雅图',
      '大峡谷',
      '黄石',
    ]),
    _Place('加拿大', 'CANADA', '🇨🇦', ['温哥华', '多伦多', '班夫']),
    _Place('墨西哥', 'MEXICO', '🇲🇽', ['坎昆']),
    _Place('危地马拉', 'GUATEMALA', '🇬🇹'),
    _Place('伯利兹', 'BELIZE', '🇧🇿'),
    _Place('萨尔瓦多', 'EL SALVADOR', '🇸🇻'),
    _Place('洪都拉斯', 'HONDURAS', '🇭🇳'),
    _Place('尼加拉瓜', 'NICARAGUA', '🇳🇮'),
    _Place('哥斯达黎加', 'COSTA RICA', '🇨🇷'),
    _Place('巴拿马', 'PANAMA', '🇵🇦'),
    _Place('古巴', 'CUBA', '🇨🇺', ['哈瓦那']),
    _Place('牙买加', 'JAMAICA', '🇯🇲'),
    _Place('海地', 'HAITI', '🇭🇹'),
    _Place('多米尼加', 'DOMINICAN REP.', '🇩🇴'),
    _Place('巴哈马', 'BAHAMAS', '🇧🇸'),
    _Place('巴巴多斯', 'BARBADOS', '🇧🇧'),
    _Place('特立尼达和多巴哥', 'TRINIDAD', '🇹🇹'),
    _Place('圣卢西亚', 'ST. LUCIA', '🇱🇨'),
    _Place('格林纳达', 'GRENADA', '🇬🇩'),
    _Place('安提瓜和巴布达', 'ANTIGUA', '🇦🇬'),
    _Place('圣基茨和尼维斯', 'ST. KITTS', '🇰🇳'),
    _Place('多米尼克', 'DOMINICA', '🇩🇲'),
    _Place('圣文森特和格林纳丁斯', 'ST. VINCENT', '🇻🇨'),
  ]),
  _Section('南美洲', '南美洲', [
    _Place('巴西', 'BRAZIL', '🇧🇷', ['里约', '亚马逊']),
    _Place('阿根廷', 'ARGENTINA', '🇦🇷', ['布宜诺斯艾利斯', '巴塔哥尼亚']),
    _Place('智利', 'CHILE', '🇨🇱', ['复活节岛', '阿塔卡马']),
    _Place('秘鲁', 'PERU', '🇵🇪', ['马丘比丘', '库斯科']),
    _Place('哥伦比亚', 'COLOMBIA', '🇨🇴'),
    _Place('委内瑞拉', 'VENEZUELA', '🇻🇪'),
    _Place('厄瓜多尔', 'ECUADOR', '🇪🇨', ['加拉帕戈斯']),
    _Place('玻利维亚', 'BOLIVIA', '🇧🇴', ['乌尤尼']),
    _Place('巴拉圭', 'PARAGUAY', '🇵🇾'),
    _Place('乌拉圭', 'URUGUAY', '🇺🇾'),
    _Place('圭亚那', 'GUYANA', '🇬🇾'),
    _Place('苏里南', 'SURINAME', '🇸🇷'),
  ]),
  _Section('大洋洲', '大洋洲', [
    _Place('澳大利亚', 'AUSTRALIA', '🇦🇺', ['悉尼', '墨尔本', '大堡礁', '黄金海岸']),
    _Place('新西兰', 'NEW ZEALAND', '🇳🇿', ['皇后镇', '奥克兰']),
    _Place('巴布亚新几内亚', 'PAPUA N.G.', '🇵🇬'),
    _Place('斐济', 'FIJI', '🇫🇯'),
    _Place('所罗门群岛', 'SOLOMON IS.', '🇸🇧'),
    _Place('瓦努阿图', 'VANUATU', '🇻🇺'),
    _Place('萨摩亚', 'SAMOA', '🇼🇸'),
    _Place('汤加', 'TONGA', '🇹🇴'),
    _Place('基里巴斯', 'KIRIBATI', '🇰🇮'),
    _Place('图瓦卢', 'TUVALU', '🇹🇻'),
    _Place('瑙鲁', 'NAURU', '🇳🇷'),
    _Place('帕劳', 'PALAU', '🇵🇼'),
    _Place('密克罗尼西亚', 'MICRONESIA', '🇫🇲'),
    _Place('马绍尔群岛', 'MARSHALL IS.', '🇲🇭'),
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
  // 子区点亮 → 上级点亮；分区顺序保证了 省 → 中国 → 亚洲 这条链能一路传上去
  for (final s in _sections) {
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
                      const SizedBox(width: 38),
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

  Widget _tile(_Place p, DateTime? at) {
    final on = at != null;
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
                        if (p.icon.isNotEmpty) ...[
                          Opacity(
                            opacity: on ? 1 : .28,
                            child: Text(
                              p.icon,
                              style: const TextStyle(fontSize: 27),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
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
