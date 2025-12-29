@echo off
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

REM 出力ディレクトリ
set OUTDIR=%~dp0output
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

echo 出力先: %OUTDIR%
echo.

REM フルアセンブリ
echo [1/5] フルアセンブリをエクスポート中...
%OPENSCAD% -o "%OUTDIR%\corosuke_full_assembly.3mf" "%~dp0corosuke_full_assembly.scad"

REM 頭部
echo [2/5] 頭部パーツをエクスポート中...
%OPENSCAD% -o "%OUTDIR%\head_face_shell.3mf" -D "head_face_shell();" "%~dp0parts_for_3mf.scad"
%OPENSCAD% -o "%OUTDIR%\head_topknot.3mf" -D "head_topknot();" "%~dp0parts_for_3mf.scad"

REM 胴体
echo [3/5] 胴体パーツをエクスポート中...
%OPENSCAD% -o "%OUTDIR%\body_torso_shell.3mf" -D "body_torso_shell();" "%~dp0parts_for_3mf.scad"

REM 腕
echo [4/5] 腕パーツをエクスポート中...
%OPENSCAD% -o "%OUTDIR%\arm_hand_right.3mf" -D "arm_hand_right();" "%~dp0parts_for_3mf.scad"

REM 刀
echo [5/5] 刀パーツをエクスポート中...
%OPENSCAD% -o "%OUTDIR%\sword_sheath.3mf" -D "sword_sheath();" "%~dp0parts_for_3mf.scad"

echo.
echo ==========================================
echo   エクスポート完了！
echo   Export Complete!
echo ==========================================
echo.
echo 出力ファイル:
dir /b "%OUTDIR%\*.3mf"
echo.
pause
