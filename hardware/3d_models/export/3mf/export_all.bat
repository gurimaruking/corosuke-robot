@echo off
chcp 65001 >nul
REM コロ助ロボット - 全パーツ3MFエクスポート
REM Corosuke Robot - Export all parts to 3MF
REM
REM 使い方: このバッチファイルをダブルクリック
REM OpenSCADがインストールされている必要があります

echo ==========================================
echo   コロ助ロボット 3MFエクスポート
echo   Corosuke Robot 3MF Export
echo ==========================================
echo.

REM OpenSCADのパス（必要に応じて変更）
set OPENSCAD="C:\Program Files\OpenSCAD\openscad.exe"
if not exist %OPENSCAD% set OPENSCAD="C:\Program Files (x86)\OpenSCAD\openscad.exe"
if not exist %OPENSCAD% (
    echo OpenSCADが見つかりません。パスを確認してください。
    echo OpenSCAD not found. Please check the path.
    pause
    exit /b 1
)

set OUTDIR=%~dp0
echo 出力先: %OUTDIR%
echo.

REM 頭部パーツ
echo [1/12] 顔シェル...
%OPENSCAD% -o "%OUTDIR%head_face.3mf" "%OUTDIR%export_head_face.scad"

echo [2/12] 右目...
%OPENSCAD% -o "%OUTDIR%head_eyeball_right.3mf" "%OUTDIR%export_head_eyeball_right.scad"

echo [3/12] 左目...
%OPENSCAD% -o "%OUTDIR%head_eyeball_left.3mf" "%OUTDIR%export_head_eyeball_left.scad"

echo [4/12] 鼻...
%OPENSCAD% -o "%OUTDIR%head_nose.3mf" "%OUTDIR%export_head_nose.scad"

echo [5/12] 丁髷...
%OPENSCAD% -o "%OUTDIR%head_topknot.3mf" "%OUTDIR%export_head_topknot.scad"

echo [6/12] 口...
%OPENSCAD% -o "%OUTDIR%head_mouth.3mf" "%OUTDIR%export_head_mouth.scad"

REM 胴体
echo [7/12] 胴体...
%OPENSCAD% -o "%OUTDIR%body_torso.3mf" "%OUTDIR%export_body_torso.scad"

REM 腕
echo [8/12] 右腕...
%OPENSCAD% -o "%OUTDIR%arm_right.3mf" "%OUTDIR%export_arm_right.scad"

echo [9/12] 左腕...
%OPENSCAD% -o "%OUTDIR%arm_left.3mf" "%OUTDIR%export_arm_left.scad"

echo [10/12] 右手...
%OPENSCAD% -o "%OUTDIR%hand_right.3mf" "%OUTDIR%export_hand_right.scad"

echo [11/12] 左手...
%OPENSCAD% -o "%OUTDIR%hand_left.3mf" "%OUTDIR%export_hand_left.scad"

REM 脚
echo [12/12] 右脚...
%OPENSCAD% -o "%OUTDIR%leg_right.3mf" "%OUTDIR%export_leg_right.scad"

echo [13/12] 左脚...
%OPENSCAD% -o "%OUTDIR%leg_left.3mf" "%OUTDIR%export_leg_left.scad"

echo [14/12] 右足...
%OPENSCAD% -o "%OUTDIR%foot_right.3mf" "%OUTDIR%export_foot_right.scad"

echo [15/12] 左足...
%OPENSCAD% -o "%OUTDIR%foot_left.3mf" "%OUTDIR%export_foot_left.scad"

REM 刀
echo [16/12] 刀...
%OPENSCAD% -o "%OUTDIR%sword_full.3mf" "%OUTDIR%export_sword_full.scad"

REM フルアセンブリ
echo [17/12] フルアセンブリ...
%OPENSCAD% -o "%OUTDIR%corosuke_full.3mf" "%OUTDIR%export_corosuke_full.scad"

echo.
echo ==========================================
echo   エクスポート完了！
echo   Export Complete!
echo ==========================================
echo.
echo 出力ファイル:
dir /b "%OUTDIR%*.3mf" 2>nul
echo.
pause
