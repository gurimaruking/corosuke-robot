"""
コロ助 胴体v3 — FreeCADネイティブ生成(Part API)。CSGインポータを使わないので確実に開ける。

使い方:
  A) GUIで マクロ > マクロ… > このファイルを選び「実行」 → 色付き・自動フィットで表示
  B) CLIで  "C:\\Program Files\\FreeCAD 1.0\\bin\\freecadcmd.exe" torso_v3_freecad.py
            → 同じ形状を torso_v3.FCStd に保存(このファイルをダブルクリックで開ける)
"""
import os
import FreeCAD as App
import Part
from FreeCAD import Vector

try:
    import FreeCADGui as Gui
    HAS_GUI = bool(getattr(App, "GuiUp", False))
except Exception:
    HAS_GUI = False

WALL, JH, JBOT, JTOP = 3.0, 165.0, 158.0, 165.0
def rin(z):
    return (JBOT + (JTOP - JBOT) * z / JH) / 2 - WALL

def _color(o, rgb, transp):
    if HAS_GUI and getattr(o, "ViewObject", None):
        o.ViewObject.ShapeColor = rgb
        o.ViewObject.Transparency = transp

def add(doc, name, shape, rgb, transp=0):
    o = doc.addObject("Part::Feature", name)
    o.Shape = shape
    _color(o, rgb, transp)
    return o

def sbox(doc, name, xa, xb, y, dy, z, dz, s, rgb):
    if s < 0:
        xa, xb = -xb, -xa            # 符号反転(mirror不使用)
    add(doc, name, Part.makeBox(xb - xa, dy, dz, Vector(xa, y, z)), rgb)

def build():
    doc = App.newDocument("KorosukeTorsoV3")
    # --- シェル(中空テーパー) ---
    shell = Part.makeCone(JBOT / 2, JTOP / 2, JH).cut(
        Part.makeCone(JBOT / 2 - WALL, JTOP / 2 - WALL, JH, Vector(0, 0, WALL)))
    cuts = [
        Part.makeCylinder(60, 7, Vector(0, 0, JH - WALL - 1)),                 # 天面開口φ120
        Part.makeBox(70, 22, 95, Vector(-35, JBOT / 2 - 16, 20)),             # 背面ハッチ
        Part.makeCylinder(6, 20, Vector(0, -JTOP / 2 - 2, 100), Vector(0, 1, 0)),  # 胸カメラ窓
    ]
    for s in (-1, 1):
        cuts.append(Part.makeCylinder(18, 30, Vector(s * (JTOP / 2 - 12), 0, 127), Vector(s, 0, 0)))  # 腕穴
    for c in cuts:
        try:
            shell = shell.cut(c)
        except Exception as e:
            App.Console.PrintWarning("cut skip: %s\n" % e)
    add(doc, "Shell", shell, (0.94, 0.56, 0.12), 55)
    # --- 搭載部品(単純プリミティブ=絶対に失敗しない) ---
    add(doc, "RDK_X5_case", Part.makeBox(62.4, 27.1, 91.4, Vector(-31.2, -13.55, WALL + 5)), (0.30, 0.69, 0.31))
    add(doc, "Battery", Part.makeBox(62, 24, 95, Vector(-31, 20, WALL)), (0.27, 0.35, 0.39))
    add(doc, "Speaker_phi50", Part.makeCylinder(25, 18.5, Vector(0, -rin(35), 35), Vector(0, 1, 0)), (0.86, 0.86, 0.86))
    for s in (-1, 1):
        sbox(doc, "ServoMount_%s" % ("R" if s > 0 else "L"), 34, 68, -25, 26, 108, 26, s, (1.0, 0.93, 0.35))
        sbox(doc, "SG90_%s" % ("R" if s > 0 else "L"), 41.1, 63.8, -21.5, 22.5, 120.95, 12.1, s, (0.10, 0.46, 0.82))
        sbox(doc, "Horn_H_%s" % ("R" if s > 0 else "L"), 44, 72, 3, 2.5, 125.5, 3, s, (0.08, 0.40, 0.75))
        sbox(doc, "Horn_V_%s" % ("R" if s > 0 else "L"), 56.5, 59.5, 3, 2.5, 113, 28, s, (0.08, 0.40, 0.75))
    doc.recompute()
    return doc

doc = build()
if HAS_GUI:
    Gui.activeDocument().activeView().viewIsometric()
    Gui.SendMsgToActiveView("ViewFit")
else:
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "torso_v3.FCStd")
    doc.saveAs(out)
    App.Console.PrintMessage("SAVED %s\n" % out)
