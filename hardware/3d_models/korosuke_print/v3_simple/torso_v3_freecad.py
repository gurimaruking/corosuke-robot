"""
コロ助 胴体v3 — FreeCADネイティブ組立(実物SG90/十字ホーンSTEP + シェル/底/蓋メッシュ)。
CSGインポータを使わないので確実に開ける。

  A) GUI: マクロ > マクロ… > このファイル > 実行  (色付き・自動フィット)
  B) CLI: "C:\\Program Files\\FreeCAD 1.0\\bin\\freecadcmd.exe" torso_v3_freecad.py
          → torso_v3.FCStd に保存(ダブルクリックで開ける)
"""
import os
import FreeCAD as App
import Part
import Mesh
from FreeCAD import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
# STEPモデルは親フォルダ(korosuke_print/)に置かれている
SNAP = os.path.join(os.path.dirname(HERE), "sg90-servomotor-arms-1.snapshot.33")
SG90_STEP = os.path.join(SNAP, "SG90_Model_A", "SG90_Model_A.step")
HORN_STEP = os.path.join(SNAP, "SG90_Arm_05_Custom", "SG90_Arm_05_Custom.step")

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

X_ROT = -90  # SG90/ホーンの向き。-90=本体を前(-Y)へ(電池と非干渉)。逆にしたい時は符号を変える。
SG_SX = 56   # 軸X。ホーン半径18が内壁(≈78.7)とクリアするよう56以内に
def imp_step(doc, path, name, target_center, rgb, xrot=X_ROT):
    """STEPを読み、軸(model+Z)を胴のY向きに回し、bbox中心を target_center に合わせる。"""
    sh = Part.Shape(); sh.read(path)
    sh.rotate((0, 0, 0), (1, 0, 0), xrot)
    c = sh.BoundBox.Center
    sh.translate((target_center[0]-c.x, target_center[1]-c.y, target_center[2]-c.z))
    return add(doc, name, sh, rgb)

def build():
    doc = App.newDocument("KorosukeTorsoV3")
    # シェル/底/蓋(サーボ台融着済み)= 印刷STLをメッシュで参照
    mesh(doc, "Shell",  "stl/shell_v3.stl",  (0.94, 0.56, 0.12))
    mesh(doc, "Bottom", "stl/bottom_v3.stl", (0.85, 0.46, 0.02))
    mesh(doc, "Lid",    "stl/lid_v3.stl",    (0.97, 0.86, 0.44))
    # 搭載部品(編集可能ソリッド)
    add(doc, "RDK_X5_case", Part.makeBox(62.4, 27.1, 91.4, Vector(-31.2, -13.55, 8)), (0.30, 0.69, 0.31))
    add(doc, "Battery",     Part.makeBox(62, 24, 95, Vector(-31, 20, 3)), (0.27, 0.35, 0.39))
    add(doc, "Speaker_phi50", Part.makeCylinder(25, 18.5, Vector(0, -76.7, 35), Vector(0, 1, 0)), (0.86, 0.86, 0.86))
    add(doc, "Camera_HBV_W202012HD", Part.makeBox(30, 14, 25, Vector(-15, -78.5, 105.5)), (0.15, 0.15, 0.15))  # 30x25x14 前面上
    # 実物SG90 + 十字ホーン(左右)。本体は前(-Y)、ホーンは軸の後ろ(y3)でX-Z面を回る。
    sgs = []
    for s in (-1, 1):
        tag = "R" if s > 0 else "L"
        sgs.append(imp_step(doc, SG90_STEP, "SG90_%s" % tag, (SG_SX*s, -10, 127), (0.10, 0.46, 0.82)))
        sgs.append(imp_step(doc, HORN_STEP, "CrossHorn_%s" % tag, (SG_SX*s, 3, 127), (0.85, 0.85, 0.88)))
    doc.recompute()
    # --- 検証: 内壁コーンより外に出ていないか(壁貫通=干渉) ---
    cavity = Part.makeCone(158/2-3, 165/2-3, 165)      # 内壁(テーパー)
    for o in sgs:
        poke = o.Shape.cut(cavity)
        vol = poke.Volume/1000 if poke.Solids else 0
        App.Console.PrintMessage("CHECK %-13s 壁外はみ出し=%.2f cm3  (0=完全に胴内)\n" % (o.Name, vol))
    return doc

doc = build()
if HAS_GUI:
    Gui.activeDocument().activeView().viewIsometric(); Gui.SendMsgToActiveView("ViewFit")
else:
    out = os.path.join(HERE, "torso_v3.FCStd"); doc.saveAs(out)
    App.Console.PrintMessage("SAVED %s\n" % out)
