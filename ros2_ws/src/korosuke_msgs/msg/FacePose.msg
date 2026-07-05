# 検出した人/顔の画面内位置 (vision_node が publish)
bool    detected  # 人を検出したか
float32 x         # 画面中心基準の水平位置 -1.0..1.0 (右+)
float32 y         # 画面中心基準の垂直位置 -1.0..1.0 (下+)
float32 size      # bbox の相対サイズ 0.0..1.0 (近さの目安)
