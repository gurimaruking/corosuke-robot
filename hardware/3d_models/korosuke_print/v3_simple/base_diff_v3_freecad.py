"""
コロ助 差動2輪ドライブベースv3(ドライブポッド方式: サーボ+タイヤを机上完組み→上から落とし込みM3×4) — FreeCADネイティブ組立(CSGインポータ不使用=確実に開ける)。

  A) GUI: マクロ > マクロ… > このファイル > 実行  (色付き・自動フィット)
  B) CLI: "C:\\Program Files\\FreeCAD 1.0\\bin\\freecadcmd.exe" base_diff_v3_freecad.py
          → base_diff_v3.FCStd に保存(ダブルクリックで開ける)

搭載(秋月完結): FS90R×2(g113206) + FS90R-Wタイヤφ60×8(g113207) + タミヤ70144キャスタ(g110372)
座標: torso_v3と同じ(Z=上, Y=前-/後+)。地面=z0, ベース天面=z45(ここに胴が載る)。
"""
import os
import FreeCAD as App
import Part
import Mesh
from FreeCAD import Vector

HERE = os.path.dirname(os.path.abspath(__file__))

try:
    import FreeCADGui as Gui
    HAS_GUI = bool(getattr(App, "GuiUp", False))
except Exception:
    HAS_GUI = False

def _color(o, rgb, transp):
    if HAS_GUI and getattr(o, "ViewObject", None):
        o.ViewObject.ShapeColor = rgb
        o.ViewObject.Transparency = transp

def add(doc, name, shape, rgb, transp=0):
    o = doc.addObject("Part::Feature", name); o.Shape = shape; _color(o, rgb, transp); return o

def mesh(doc, name, stl, rgb):
    m = Mesh.Mesh(os.path.join(HERE, stl))
    o = doc.addObject("Mesh::Feature", name); o.Mesh = m
    if HAS_GUI and getattr(o, "ViewObject", None):
        o.ViewObject.ShapeColor = rgb
    return o

# ---- base_diff_v1.scad と同じパラメータ ----
WX = 65        # 車輪中心X
AXLE_Z = 30    # 車軸高さ(φ60)
WHEEL_D, WHEEL_W = 60, 8
SVL, SVW, SVH = 23.2, 12.5, 22.4   # FS90R 実寸
BF_X, BWALL = 55, 3               # バルクヘッド外面X/厚(v2)
SV_INB = 18.4                      # フランジ面から内側の本体深さ
CAST_Y, GC = 58, 11

def build():
    doc = App.newDocument("KorosukeDiffBaseV3")
    # 印刷ベース = STLメッシュ
    mesh(doc, "DriveBase", "stl/base_diff_v3.stl", (0.85, 0.46, 0.02))
    # ドライブポッド×2(同一部品。左は180°回転)
    for ang, tag in ((0, "R"), (180, "L")):
        p = mesh(doc, "DrivePod_%s" % tag, "stl/base_diff_v3_pod.stl", (0.94, 0.56, 0.12))
        p.Placement = App.Placement(Vector(0, 0, 0), App.Rotation(Vector(0, 0, 1), ang))
    for s, tag in ((-1, "L"), (1, "R")):
        # FS90R-W タイヤ(φ60×8, 軸=X)
        add(doc, "Tire_FS90RW_%s" % tag,
            Part.makeCylinder(WHEEL_D/2, WHEEL_W, Vector(s*WX - s*WHEEL_W/2, 0, AXLE_Z), Vector(s, 0, 0)),
            (0.56, 0.79, 0.98))
        # FS90R 本体(バルクヘッド内面x=±52から内側へ18.4)
        xin = BF_X - BWALL
        add(doc, "FS90R_%s" % tag,
            Part.makeBox(SV_INB, SVL, SVW, Vector(min(s*(xin-SV_INB), s*xin), -SVL/2, AXLE_Z - SVW/2)),
            (0.10, 0.46, 0.82))
    # タミヤ70144 ボールキャスタ(前後, 高さ11)
    for t, tag in ((-1, "F"), (1, "B")):
        add(doc, "Caster70144_%s" % tag,
            Part.makeCone(9, 5, GC, Vector(0, t*CAST_Y, 0)), (0.62, 0.62, 0.62))
    # RDKケーブル束(胴からφ90井戸をまっすぐ降りる想定)
    add(doc, "CableBundle_phi86", Part.makeCylinder(43, 70, Vector(0, 0, GC)), (0.80, 0.10, 0.10), 70)
    # サーボ用LiPo(小型2S級, 井戸の後ろ)
    add(doc, "Servo_LiPo", Part.makeBox(60, 28, 20, Vector(-30, 38, GC+3)), (0.27, 0.35, 0.39))
    doc.recompute()
    return doc

doc = build()
if HAS_GUI:
    Gui.activeDocument().activeView().viewIsometric(); Gui.SendMsgToActiveView("ViewFit")
else:
    out = os.path.join(HERE, "base_diff_v3.FCStd"); doc.saveAs(out)
    App.Console.PrintMessage("SAVED %s\n" % out)
