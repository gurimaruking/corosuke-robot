"""
コロ助ロボット - ホームサーバー
Corosuke Robot - Home Server

LLM API + VOICEVOX連携サーバー
ESP32からのリクエストを処理し、音声合成を行う
"""

import os
import io
import json
import asyncio
from typing import Optional
from pathlib import Path

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import httpx
from dotenv import load_dotenv

from corosuke_personality import (
    COROSUKE_SYSTEM_PROMPT,
    VOICEVOX_SPEAKER_ID,
    detect_expression
)

# 環境変数読み込み
load_dotenv()

# =============================================================================
# 設定
# =============================================================================

# サーバー設定
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8080"))

# LLM API設定
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

# VOICEVOX設定
VOICEVOX_HOST = os.getenv("VOICEVOX_HOST", "http://localhost:50021")

# 音声ファイル保存ディレクトリ
AUDIO_DIR = Path("audio_cache")
AUDIO_DIR.mkdir(exist_ok=True)

# =============================================================================
# FastAPIアプリ
# =============================================================================

app = FastAPI(
    title="コロ助ロボット ホームサーバー",
    description="Corosuke Robot Home Server - LLM & TTS Integration",
    version="1.0.0"
)

# 静的ファイル（音声キャッシュ）
app.mount("/audio", StaticFiles(directory=str(AUDIO_DIR)), name="audio")

# =============================================================================
# データモデル
# =============================================================================

class ChatRequest(BaseModel):
    message: str
    context: Optional[list] = None

class ChatResponse(BaseModel):
    response: str
    expression: str
    audio_url: Optional[str] = None

class SpeakRequest(BaseModel):
    text: str
    speaker_id: Optional[int] = VOICEVOX_SPEAKER_ID

class SpeakResponse(BaseModel):
    audio_url: str
    duration_ms: int

class CommandRequest(BaseModel):
    command: str
    params: Optional[dict] = None

# =============================================================================
# 会話履歴
# =============================================================================

conversation_history = []
MAX_HISTORY = 10

# =============================================================================
# LLM連携
# =============================================================================

async def chat_with_claude(message: str) -> str:
    """Claude APIで会話"""
    if not ANTHROPIC_API_KEY:
        return "APIキーが設定されていないナリ..."

    global conversation_history

    # 履歴に追加
    conversation_history.append({
        "role": "user",
        "content": message
    })

    # 履歴が長すぎたら削除
    if len(conversation_history) > MAX_HISTORY * 2:
        conversation_history = conversation_history[-MAX_HISTORY * 2:]

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "Content-Type": "application/json",
                    "x-api-key": ANTHROPIC_API_KEY,
                    "anthropic-version": "2023-06-01"
                },
                json={
                    "model": "claude-3-haiku-20240307",
                    "max_tokens": 256,
                    "system": COROSUKE_SYSTEM_PROMPT,
                    "messages": conversation_history
                },
                timeout=30.0
            )

            if response.status_code == 200:
                data = response.json()
                assistant_message = data["content"][0]["text"]

                # 履歴に追加
                conversation_history.append({
                    "role": "assistant",
                    "content": assistant_message
                })

                return assistant_message
            else:
                return f"エラーが発生したナリ... (ステータス: {response.status_code})"

        except Exception as e:
            return f"通信エラーナリ: {str(e)}"


async def chat_with_openai(message: str) -> str:
    """OpenAI APIで会話（フォールバック用）"""
    if not OPENAI_API_KEY:
        return "OpenAI APIキーが設定されていないナリ..."

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {OPENAI_API_KEY}"
                },
                json={
                    "model": "gpt-3.5-turbo",
                    "max_tokens": 256,
                    "messages": [
                        {"role": "system", "content": COROSUKE_SYSTEM_PROMPT},
                        {"role": "user", "content": message}
                    ]
                },
                timeout=30.0
            )

            if response.status_code == 200:
                data = response.json()
                return data["choices"][0]["message"]["content"]
            else:
                return "エラーが発生したナリ..."

        except Exception as e:
            return f"通信エラーナリ: {str(e)}"

# =============================================================================
# VOICEVOX連携
# =============================================================================

async def synthesize_voice(text: str, speaker_id: int = VOICEVOX_SPEAKER_ID) -> tuple[bytes, int]:
    """VOICEVOXで音声合成"""
    async with httpx.AsyncClient() as client:
        # 音声クエリ作成
        query_response = await client.post(
            f"{VOICEVOX_HOST}/audio_query",
            params={"text": text, "speaker": speaker_id},
            timeout=30.0
        )

        if query_response.status_code != 200:
            raise HTTPException(status_code=500, detail="音声クエリ作成失敗")

        query = query_response.json()

        # 速度調整（コロ助は少し早口）
        query["speedScale"] = 1.2
        query["pitchScale"] = 0.05  # 少し高め

        # 音声合成
        synth_response = await client.post(
            f"{VOICEVOX_HOST}/synthesis",
            params={"speaker": speaker_id},
            json=query,
            timeout=60.0
        )

        if synth_response.status_code != 200:
            raise HTTPException(status_code=500, detail="音声合成失敗")

        audio_data = synth_response.content

        # 音声の長さを計算（概算）
        duration_ms = int(len(audio_data) / 44100 * 1000 / 2)  # 16bit mono概算

        return audio_data, duration_ms

# =============================================================================
# APIエンドポイント
# =============================================================================

@app.get("/")
async def root():
    """ヘルスチェック"""
    return {
        "status": "running",
        "name": "コロ助ロボット ホームサーバー",
        "version": "1.0.0"
    }


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """LLMと会話してレスポンスを返す"""
    # LLMで応答生成
    if ANTHROPIC_API_KEY:
        response_text = await chat_with_claude(request.message)
    elif OPENAI_API_KEY:
        response_text = await chat_with_openai(request.message)
    else:
        response_text = "ワガハイはコロ助ナリ！APIキーを設定してほしいナリ！"

    # 表情を検出
    expression = detect_expression(response_text)

    return ChatResponse(
        response=response_text,
        expression=expression,
        audio_url=None
    )


@app.post("/speak", response_model=SpeakResponse)
async def speak(request: SpeakRequest):
    """テキストを音声合成して返す"""
    try:
        # 音声合成
        audio_data, duration_ms = await synthesize_voice(
            request.text,
            request.speaker_id or VOICEVOX_SPEAKER_ID
        )

        # ファイルに保存
        import hashlib
        filename = hashlib.md5(request.text.encode()).hexdigest()[:16] + ".wav"
        filepath = AUDIO_DIR / filename

        with open(filepath, "wb") as f:
            f.write(audio_data)

        return SpeakResponse(
            audio_url=f"/audio/{filename}",
            duration_ms=duration_ms
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/chat_and_speak")
async def chat_and_speak(request: ChatRequest):
    """LLMで会話して音声も生成"""
    # LLMで応答生成
    if ANTHROPIC_API_KEY:
        response_text = await chat_with_claude(request.message)
    elif OPENAI_API_KEY:
        response_text = await chat_with_openai(request.message)
    else:
        response_text = "ワガハイはコロ助ナリ！"

    # 表情を検出
    expression = detect_expression(response_text)

    # 音声合成
    try:
        audio_data, duration_ms = await synthesize_voice(response_text)

        import hashlib
        filename = hashlib.md5(response_text.encode()).hexdigest()[:16] + ".wav"
        filepath = AUDIO_DIR / filename

        with open(filepath, "wb") as f:
            f.write(audio_data)

        audio_url = f"/audio/{filename}"
    except:
        audio_url = None
        duration_ms = 0

    return {
        "response": response_text,
        "expression": expression,
        "audio_url": audio_url,
        "duration_ms": duration_ms
    }


@app.post("/command")
async def command(request: CommandRequest):
    """ロボットへのコマンドを処理"""
    cmd = request.command.lower()

    if cmd == "greet":
        return await chat_and_speak(ChatRequest(message="こんにちは！自己紹介して"))

    elif cmd == "status":
        return {
            "status": "ok",
            "message": "ワガハイは元気ナリ！"
        }

    elif cmd == "reset":
        global conversation_history
        conversation_history = []
        return {
            "status": "ok",
            "message": "会話履歴をリセットしたナリ！"
        }

    else:
        return {
            "status": "unknown",
            "message": f"'{cmd}'というコマンドは知らないナリ..."
        }


@app.get("/expressions")
async def get_expressions():
    """使用可能な表情一覧"""
    return {
        "expressions": [
            "neutral",
            "happy",
            "sad",
            "surprised",
            "angry",
            "thinking",
            "excited",
            "sleepy"
        ]
    }

# =============================================================================
# WebSocket（リアルタイム通信用）
# =============================================================================

connected_clients = set()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket接続（ESP32との双方向通信用）"""
    await websocket.accept()
    connected_clients.add(websocket)

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)

            if message.get("type") == "chat":
                # 会話処理
                response = await chat_with_claude(message.get("text", ""))
                expression = detect_expression(response)

                await websocket.send_json({
                    "type": "response",
                    "text": response,
                    "expression": expression
                })

            elif message.get("type") == "ping":
                await websocket.send_json({"type": "pong"})

    except WebSocketDisconnect:
        connected_clients.remove(websocket)


async def broadcast(message: dict):
    """全クライアントにブロードキャスト"""
    for client in connected_clients:
        try:
            await client.send_json(message)
        except:
            pass

# =============================================================================
# メイン
# =============================================================================

if __name__ == "__main__":
    import uvicorn

    print("=" * 50)
    print("  コロ助ロボット ホームサーバー")
    print("  Corosuke Robot Home Server v1.0")
    print("=" * 50)
    print(f"  Server: http://{HOST}:{PORT}")
    print(f"  VOICEVOX: {VOICEVOX_HOST}")
    print(f"  Claude API: {'設定済み' if ANTHROPIC_API_KEY else '未設定'}")
    print(f"  OpenAI API: {'設定済み' if OPENAI_API_KEY else '未設定'}")
    print("=" * 50)

    uvicorn.run(app, host=HOST, port=PORT)
