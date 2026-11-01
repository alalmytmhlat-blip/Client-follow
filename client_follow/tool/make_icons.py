"""يولّد أيقونات التطبيق (قابلة للتكيّف + قديمة + أيقونة الإشعار) بدون أي اعتماد خارجي غير Pillow"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), '..', 'android_overrides', 'res')
TEAL_TOP = (18, 156, 168)
TEAL_BOT = (6, 74, 86)
AMBER = (255, 176, 32)
DARK = (6, 74, 86)
WHITE = (255, 255, 255)
SS = 1296  # لوحة 432*3

def gradient(size):
    img = Image.new('RGB', (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (0.65 * y + 0.35 * x) / size
            px[x, y] = tuple(int(TEAL_TOP[i] + (TEAL_BOT[i] - TEAL_TOP[i]) * t) for i in range(3))
    return img

def foreground(size=SS):
    """عميل (رأس + كتفان) مع شارة ساعة كهرمانية = موعد متابعة"""
    s = size
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    dx = -0.035
    # الرأس
    cx, cy, r = (0.47 + dx) * s, 0.385 * s, 0.092 * s
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=WHITE)
    # الكتفان
    d.pieslice(((0.285 + dx) * s, 0.50 * s, (0.655 + dx) * s, 1.02 * s), 180, 360, fill=WHITE)
    # الشارة
    bx, by = (0.665 + dx) * s, 0.655 * s
    ro = 0.142 * s
    d.ellipse((bx - ro, by - ro, bx + ro, by + ro), fill=DARK)
    rb = 0.118 * s
    d.ellipse((bx - rb, by - rb, bx + rb, by + rb), fill=AMBER)
    rw = 0.088 * s
    d.ellipse((bx - rw, by - rw, bx + rw, by + rw), outline=WHITE, width=int(0.014 * s))
    w = int(0.017 * s)
    d.line((bx, by, bx, by - 0.062 * s), fill=WHITE, width=w)
    d.line((bx, by, bx + 0.046 * s, by + 0.018 * s), fill=WHITE, width=w)
    for px_, py_ in ((bx, by - 0.062 * s), (bx + 0.046 * s, by + 0.018 * s), (bx, by)):
        d.ellipse((px_ - w / 2, py_ - w / 2, px_ + w / 2, py_ + w / 2), fill=WHITE)
    return im

def legacy(fg, size):
    """أيقونة كاملة بمربع دائري الزوايا للإصدارات القديمة"""
    big = 1024
    bg = gradient(big).convert('RGBA')
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big, big), radius=int(big * 0.22), fill=255)
    bg.putalpha(mask)
    # اقتصاص المنطقة الآمنة (72/108) ثم تكبيرها
    c = int(fg.width * (1 - 72 / 108) / 2)
    crop = fg.crop((c, c, fg.width - c, fg.height - c)).resize((int(big * 0.92),) * 2, Image.LANCZOS)
    off = (big - crop.width) // 2
    bg.alpha_composite(crop, (off, off))
    return bg.resize((size, size), Image.LANCZOS)

def notif_icon(size):
    """أيقونة إشعار أحادية (بيضاء على شفاف): جرس"""
    s = 960
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    W = WHITE
    d.ellipse((0.22 * s, 0.14 * s, 0.78 * s, 0.70 * s), fill=W)
    d.polygon([(0.22 * s, 0.42 * s), (0.78 * s, 0.42 * s), (0.88 * s, 0.76 * s), (0.12 * s, 0.76 * s)], fill=W)
    d.rounded_rectangle((0.10 * s, 0.72 * s, 0.90 * s, 0.80 * s), radius=int(0.04 * s), fill=W)
    d.ellipse((0.40 * s, 0.78 * s, 0.60 * s, 0.94 * s), fill=W)
    d.ellipse((0.44 * s, 0.06 * s, 0.56 * s, 0.17 * s), fill=W)
    return im.resize((size, size), Image.LANCZOS)

dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
fg = foreground()
for name, m in dens.items():
    d = os.path.join(OUT, f'mipmap-{name}')
    os.makedirs(d, exist_ok=True)
    legacy(fg, int(48 * m)).save(os.path.join(d, 'ic_launcher.png'))
    fg.resize((int(108 * m),) * 2, Image.LANCZOS).save(os.path.join(d, 'ic_launcher_foreground.png'))
    gradient(int(108 * m * 1)).save(os.path.join(d, 'ic_launcher_background.png'))
    dd = os.path.join(OUT, f'drawable-{name}')
    os.makedirs(dd, exist_ok=True)
    notif_icon(int(24 * m)).save(os.path.join(dd, 'ic_stat_notify.png'))

ad = os.path.join(OUT, 'mipmap-anydpi-v26')
os.makedirs(ad, exist_ok=True)
xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''
open(os.path.join(ad, 'ic_launcher.xml'), 'w').write(xml)

# معاينة 512
legacy(fg, 512).save(os.path.join(os.path.dirname(__file__), 'icon_preview_512.png'))
print('icons done')
