#!/usr/bin/env python3
"""生成 14 枚荣誉奖杯图标（透明底 PNG 504×504）。

设计：同一副金色杯身 + 底座（成套感），杯面上换徽记、换该成就的主色。
先出 SVG，再用 Chrome headless 光栅化成透明底 PNG。
"""
import subprocess, pathlib, sys

OUT = pathlib.Path(sys.argv[1])
TMP = pathlib.Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# slug, 主色(取自 tree_page.dart 的 achievements), 徽记
def emblem_target(c):   # 🎯 靶心
    return f'''
    <circle cx="252" cy="196" r="52" fill="none" stroke="{c}" stroke-width="16"/>
    <circle cx="252" cy="196" r="26" fill="none" stroke="{c}" stroke-width="14"/>
    <circle cx="252" cy="196" r="6" fill="{c}"/>'''

def emblem_check(c):    # ✅ 对勾
    return f'''
    <path d="M206 198 l30 32 l64 -74" fill="none" stroke="{c}"
          stroke-width="22" stroke-linecap="round" stroke-linejoin="round"/>'''

def emblem_100(c):      # 💯 一百
    return f'''
    <text x="252" y="222" text-anchor="middle" font-family="Helvetica,Arial"
          font-size="86" font-weight="700" fill="{c}">100</text>'''

def emblem_flame(c):    # 🔥 火苗
    return f'''
    <path d="M252 130 c34 40 52 60 52 92 a52 52 0 0 1 -104 0
             c0 -22 14 -36 26 -52 c6 20 16 26 16 26 c0 -26 4 -46 10 -66 z"
          fill="{c}"/>'''

def emblem_calendar(c): # 📆 日历
    return f'''
    <rect x="196" y="152" width="112" height="98" rx="14" fill="none"
          stroke="{c}" stroke-width="15"/>
    <path d="M196 186 h112" stroke="{c}" stroke-width="15"/>
    <path d="M222 134 v30 M282 134 v30" stroke="{c}" stroke-width="15" stroke-linecap="round"/>
    <circle cx="228" cy="218" r="9" fill="{c}"/>
    <circle cx="276" cy="218" r="9" fill="{c}"/>'''

def emblem_mountain(c): # 🏔️ 山峰
    return f'''
    <path d="M186 250 l44 -74 l30 40 l26 -46 l32 80 z" fill="{c}"/>
    <path d="M230 176 l16 26 l-32 0 z" fill="#FFFFFF" opacity=".85"/>'''

def emblem_star(c):     # ⭐ 单星
    return f'''<path d="{star_path(252,198,58,26,5)}" fill="{c}"/>'''

def emblem_stars(c):    # 🌟 群星
    return (f'<path d="{star_path(252,186,42,19,5)}" fill="{c}"/>'
            f'<path d="{star_path(200,236,24,11,5)}" fill="{c}" opacity=".75"/>'
            f'<path d="{star_path(304,236,24,11,5)}" fill="{c}" opacity=".75"/>')

def emblem_crown(c):    # 👑 皇冠
    return f'''
    <path d="M192 240 l-10 -84 l40 34 l30 -56 l30 56 l40 -34 l-10 84 z" fill="{c}"/>
    <rect x="192" y="248" width="120" height="18" rx="8" fill="{c}"/>'''

def emblem_half(c):     # 🌗 过半
    return f'''
    <circle cx="252" cy="196" r="56" fill="none" stroke="{c}" stroke-width="15"/>
    <path d="M252 140 a56 56 0 0 1 0 112 z" fill="{c}"/>'''

def emblem_puzzle(c):   # 🧩 拼图
    return f'''
    <mask id="mpz">
      <rect x="150" y="100" width="204" height="204" fill="black"/>
      <rect x="204" y="152" width="96" height="96" rx="14" fill="white"/>
      <circle cx="252" cy="152" r="22" fill="white"/>
      <circle cx="204" cy="200" r="22" fill="black"/>
    </mask>
    <rect x="150" y="100" width="204" height="204" fill="{c}" mask="url(#mpz)"/>'''

def emblem_camera(c):   # 📸 相机
    return f'''
    <rect x="186" y="160" width="132" height="92" rx="16" fill="none"
          stroke="{c}" stroke-width="15"/>
    <path d="M222 160 l12 -20 h36 l12 20" fill="none" stroke="{c}"
          stroke-width="15" stroke-linejoin="round"/>
    <circle cx="252" cy="208" r="26" fill="none" stroke="{c}" stroke-width="15"/>'''

def emblem_pen(c):      # 📝 笔
    return f'''
    <g transform="rotate(45 252 196)">
      <rect x="236" y="148" width="32" height="72" fill="{c}"/>
      <path d="M236 220 h32 l-16 26 z" fill="{c}"/>
      <rect x="236" y="132" width="32" height="18" rx="5" fill="#FFFFFF" opacity=".7"/>
      <path d="M252 152 v66" stroke="#FFFFFF" stroke-width="4" opacity=".35"/>
    </g>
    <rect x="200" y="256" width="104" height="12" rx="6" fill="{c}" opacity=".75"/>'''

def emblem_letter(c):   # ✉️ 信封
    return f'''
    <rect x="188" y="156" width="128" height="94" rx="14" fill="none"
          stroke="{c}" stroke-width="15"/>
    <path d="M188 170 l64 50 l64 -50" fill="none" stroke="{c}"
          stroke-width="15" stroke-linejoin="round"/>'''

def star_path(cx, cy, ro, ri, n):
    import math
    pts = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = -math.pi / 2 + i * math.pi / n
        pts.append(f"{cx + r * math.cos(a):.1f} {cy + r * math.sin(a):.1f}")
    return "M" + " L".join(pts) + " Z"

def lighten(hexc, t=.42):
    """徽记压在深色盘上，主色太暗会糊；统一往白里提，保住辨识度也保住对比。"""
    r, g, b = (int(hexc[i:i + 2], 16) for i in (1, 3, 5))
    f = lambda v: int(v + (255 - v) * t)
    return f"#{f(r):02X}{f(g):02X}{f(b):02X}"

ICONS = [
    ("first_task",   "#6FA8DC", emblem_target),
    ("task_10",      "#5EB87C", emblem_check),
    ("task_100",     "#B07E2E", emblem_100),
    ("streak_3",     "#E0855A", emblem_flame),
    ("streak_7",     "#D96A8B", emblem_calendar),
    ("streak_30",    "#8B5AD9", emblem_mountain),
    ("first_wish",   "#F3C877", emblem_star),
    ("wish_5",       "#E8B44C", emblem_stars),
    ("wish_10",      "#DA9A2B", emblem_crown),
    ("half_way",     "#7A8FD8", emblem_half),
    ("first_step",   "#4FA394", emblem_puzzle),
    ("first_photo",  "#6A5AE0", emblem_camera),
    ("first_note",   "#5C8A6E", emblem_pen),
    ("first_letter", "#A06AD8", emblem_letter),
]

SVG = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 504 504" width="504" height="504">
<defs>
  <linearGradient id="gold" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#FFF0C8"/><stop offset=".35" stop-color="#F3C877"/>
    <stop offset=".7" stop-color="#C98F35"/><stop offset="1" stop-color="#FFE9B0"/>
  </linearGradient>
  <linearGradient id="goldDeep" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#E9BC6A"/><stop offset="1" stop-color="#9A6A22"/>
  </linearGradient>
  <radialGradient id="face" cx=".35" cy=".3" r=".85">
    <stop offset="0" stop-color="#2A3050"/><stop offset="1" stop-color="#141830"/>
  </radialGradient>
</defs>

<!-- 把手 -->
<path d="M162 156 c-46 0 -60 30 -60 56 c0 40 34 62 66 66"
      fill="none" stroke="url(#goldDeep)" stroke-width="24" stroke-linecap="round"/>
<path d="M342 156 c46 0 60 30 60 56 c0 40 -34 62 -66 66"
      fill="none" stroke="url(#goldDeep)" stroke-width="24" stroke-linecap="round"/>

<!-- 杯身 -->
<path d="M148 120 h208 v92 c0 62 -46 108 -104 108 s-104 -46 -104 -108 z"
      fill="url(#gold)"/>
<!-- 杯口高光条 -->
<rect x="140" y="108" width="224" height="26" rx="13" fill="url(#gold)"/>
<rect x="164" y="114" width="70" height="10" rx="5" fill="#FFFFFF" opacity=".55"/>

<!-- 杯面（放徽记的深色盘） -->
<circle cx="252" cy="200" r="78" fill="url(#face)"/>
<circle cx="252" cy="200" r="78" fill="none" stroke="url(#goldDeep)" stroke-width="8"/>
<g transform="translate(252 200) scale(.88) translate(-252 -200)">__EMBLEM__</g>

<!-- 杯柄与底座 -->
<path d="M232 322 h40 v34 h-40 z" fill="url(#goldDeep)"/>
<path d="M196 356 h112 l-12 34 h-88 z" fill="url(#gold)"/>
<rect x="168" y="390" width="168" height="30" rx="12" fill="url(#goldDeep)"/>
<rect x="150" y="418" width="204" height="34" rx="15" fill="url(#gold)"/>
<rect x="176" y="426" width="60" height="9" rx="4" fill="#FFFFFF" opacity=".45"/>
</svg>
'''

for slug, color, emblem in ICONS:
    svg = SVG.replace("__EMBLEM__", emblem(lighten(color)))
    f = TMP / f"{slug}.svg"
    f.write_text(svg)
    subprocess.run([
        CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--force-device-scale-factor=1",
        "--default-background-color=00000000",
        f"--screenshot={OUT / (slug + '.png')}",
        "--window-size=504,504", f.as_uri(),
    ], check=True, capture_output=True)
    print("✓", slug)
print(f"\n共 {len(ICONS)} 枚 →", OUT)
