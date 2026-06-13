#!/usr/bin/env python3
"""ansi2html.py — convert ANSI (incl. xterm-256 + basic SGR) on stdin to HTML
spans on stdout. Used by preview-html to render the prompt themes / MOTD into a
browser-viewable gallery. Intentionally small: handles fg/bg 256, basic 30-37/
90-97 + 40-47/100-107, bold, and reset — which is all our prompts emit."""
import sys, re

def xterm256(n):
    if n < 16:
        base = [(0,0,0),(205,0,0),(0,205,0),(205,205,0),(0,0,238),(205,0,205),
                (0,205,205),(229,229,229),(127,127,127),(255,0,0),(0,255,0),
                (255,255,0),(92,92,255),(255,0,255),(0,255,255),(255,255,255)]
        return base[n]
    if n < 232:
        n -= 16
        r, g, b = n//36, (n//6) % 6, n % 6
        conv = lambda v: 0 if v == 0 else 55 + v*40
        return conv(r), conv(g), conv(b)
    v = 8 + (n-232)*10
    return v, v, v

BASIC = {30:(0,0,0),31:(205,0,0),32:(0,205,0),33:(205,205,0),34:(0,0,238),
         35:(205,0,205),36:(0,205,205),37:(229,229,229),
         90:(127,127,127),91:(255,0,0),92:(0,255,0),93:(255,255,0),
         94:(92,92,255),95:(255,0,255),96:(0,255,255),97:(255,255,255)}

def hexc(rgb): return "#%02x%02x%02x" % rgb

def esc(s):
    return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

def convert(text):
    # Drop private-mode sequences (e.g. chafa's cursor hide/show \e[?25l / \e[?25h)
    # and any non-SGR CSI; we only interpret colour/style (SGR, ending in 'm').
    text = re.sub(r'\x1b\[\?[0-9;]*[A-Za-z]', '', text)
    text = re.sub(r'\x1b\[[0-9;]*[A-LN-Za-ln-z]', '', text)
    out = []
    fg = bg = None
    bold = reverse = False
    open_span = False
    def close():
        nonlocal open_span
        if open_span:
            out.append("</span>"); open_span = False
    def opn():
        nonlocal open_span
        efg, ebg = (bg, fg) if reverse else (fg, bg)
        styles = []
        if efg: styles.append("color:%s" % hexc(efg))
        if ebg: styles.append("background:%s" % hexc(ebg))
        if bold: styles.append("font-weight:700")
        if styles:
            out.append('<span style="%s">' % ";".join(styles)); open_span = True
    tokens = re.split(r'(\x1b\[[0-9;]*m)', text)
    for tok in tokens:
        m = re.match(r'\x1b\[([0-9;]*)m', tok)
        if not m:
            if tok:
                if not open_span and (fg or bg or bold or reverse): opn()
                out.append(esc(tok))
            continue
        params = [int(x) for x in m.group(1).split(';') if x != ''] or [0]
        close()
        j = 0
        while j < len(params):
            p = params[j]
            if p == 0: fg = bg = None; bold = reverse = False
            elif p == 1: bold = True
            elif p == 22: bold = False
            elif p == 7: reverse = True
            elif p == 27: reverse = False
            elif p == 38 and j+4 < len(params) and params[j+1] == 2:
                fg = (params[j+2], params[j+3], params[j+4]); j += 4   # 24-bit fg
            elif p == 48 and j+4 < len(params) and params[j+1] == 2:
                bg = (params[j+2], params[j+3], params[j+4]); j += 4   # 24-bit bg
            elif p == 38 and j+2 < len(params) and params[j+1] == 5:
                fg = xterm256(params[j+2]); j += 2
            elif p == 48 and j+2 < len(params) and params[j+1] == 5:
                bg = xterm256(params[j+2]); j += 2
            elif p in BASIC: fg = BASIC[p]
            elif 40 <= p <= 47 or 100 <= p <= 107:
                bg = BASIC[p-10]
            elif p == 39: fg = None
            elif p == 49: bg = None
            j += 1
        # carry state into following text via fg/bg/bold/reverse; span opened lazily
    close()
    return "".join(out)

if __name__ == "__main__":
    sys.stdout.write(convert(sys.stdin.read()))
