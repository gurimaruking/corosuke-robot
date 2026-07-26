# コロ助の目コマンド (ESP32-S3 目コプロセッサへ)
string  emotion   # neutral | happy | sad | angry | surprised | sleepy | thinking | dead
float32 gaze_x    # 視線 左右 -1.0..1.0 (右+)
float32 gaze_y    # 視線 上下 -1.0..1.0 (下+)
bool    blink     # true でまばたき1回
