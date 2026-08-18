#!/usr/bin/env python3
"""Generate local voice assets from DashScope manifests.

Usage:
  DASHSCOPE_API_KEY=... python3 scripts/generate_voice_assets.py
  DASHSCOPE_API_KEY=... python3 scripts/generate_voice_assets.py --language zh-Hans --force
"""

from __future__ import annotations

import argparse
import base64
import http.client
import json
import mimetypes
import os
import socket
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
VOICE_ROOT = ROOT / "PaodekuaiNative" / "Resources" / "Voice.bundle"
SUPPORTED_EXTENSIONS = ("m4a", "caf", "wav", "mp3", "aac")
CONTENT_TYPE_EXTENSIONS = {
    "audio/aac": "aac",
    "audio/mp4": "m4a",
    "audio/mpeg": "mp3",
    "audio/mp3": "mp3",
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "audio/wave": "wav",
    "audio/vnd.wave": "wav",
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate DashScope TTS assets for Paodekuai.")
    parser.add_argument("--language", choices=("zh-Hans", "en"), help="Only generate one language.")
    parser.add_argument("--force", action="store_true", help="Regenerate files that already exist.")
    parser.add_argument("--keys", help="Comma-separated clip keys to generate.")
    parser.add_argument("--retries", type=int, default=3, help="Retries per clip after transient failures.")
    parser.add_argument("--sleep", type=float, default=0.2, help="Delay between API calls.")
    parser.add_argument("--start-at", help="Skip clips until this key is reached.")
    parser.add_argument("--timeout", type=float, default=45, help="Network timeout in seconds.")
    args = parser.parse_args()

    api_key = os.environ.get("DASHSCOPE_API_KEY")
    if not api_key:
        print("DASHSCOPE_API_KEY is required.", file=sys.stderr)
        return 2

    languages = [args.language] if args.language else ["zh-Hans", "en"]
    requested_keys = set(args.keys.split(",")) if args.keys else None
    for language in languages:
        manifest_path = VOICE_ROOT / language / "voice_assets.json"
        manifest = read_json(manifest_path)
        generator = manifest["generator"]
        should_generate = args.start_at is None
        for clip in manifest["clips"]:
            if requested_keys is not None and clip["key"] not in requested_keys:
                continue
            if not should_generate:
                should_generate = clip["key"] == args.start_at
                if not should_generate:
                    continue

            existing = existing_audio_path(manifest_path.parent, clip["key"])
            if existing and not args.force:
                print(f"skip {language}/{clip['key']} (exists: {existing.name})", flush=True)
                continue

            print(f"generate {language}/{clip['key']}: {clip['text']}", flush=True)
            audio_bytes, extension = synthesize_with_retries(
                api_key=api_key,
                language=manifest["language"],
                generator=generator,
                text=clip["text"],
                retries=max(1, args.retries),
                timeout=args.timeout,
            )
            output_path = manifest_path.parent / f"{clip['key']}.{extension}"
            output_path.write_bytes(audio_bytes)
            print(f"wrote {output_path.relative_to(ROOT)} ({len(audio_bytes)} bytes)", flush=True)
            time.sleep(args.sleep)

    return 0


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def existing_audio_path(directory: Path, key: str) -> Path | None:
    for ext in SUPPORTED_EXTENSIONS:
        path = directory / f"{key}.{ext}"
        if path.exists() and path.stat().st_size > 0:
            return path
    return None


def synthesize_clip(
    api_key: str,
    language: str,
    generator: dict[str, str],
    text: str,
    timeout: float,
) -> tuple[bytes, str]:
    if language == "zh-Hans":
        payload = {
            "model": generator["model"],
            "input": {
                "text": text,
                "voice": generator["voice"],
                "format": "mp3",
                "sample_rate": 24000,
            },
        }
        if text == "连对":
            payload["input"]["text"] = "<speak rate=\"1.15\">连对</speak>"
            payload["input"]["enable_ssml"] = True
    else:
        payload = {
            "model": generator["model"],
            "input": {
                "text": text,
                "voice": generator["voice"],
                "language_type": "English",
            },
        }

    response_body, content_type = post_json(generator["endpoint"], api_key, payload, timeout)
    if content_type.startswith("audio/"):
        return response_body, extension_for_content_type(content_type, "mp3")

    response = json.loads(response_body.decode("utf-8"))
    audio_url = find_audio_url(response)
    if audio_url:
        return download_audio(audio_url, timeout)

    audio_data = find_base64_audio(response)
    if audio_data:
        return audio_data, "mp3"

    raise RuntimeError(f"No audio payload found in response: {json.dumps(response, ensure_ascii=False)[:500]}")


def synthesize_with_retries(
    api_key: str,
    language: str,
    generator: dict[str, str],
    text: str,
    retries: int,
    timeout: float,
) -> tuple[bytes, str]:
    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            return synthesize_clip(api_key, language, generator, text, timeout)
        except (RuntimeError, socket.timeout, TimeoutError, urllib.error.URLError, http.client.RemoteDisconnected) as error:
            last_error = error
            if attempt == retries:
                break
            delay = min(2 ** (attempt - 1), 8)
            print(f"retry {attempt}/{retries} after error: {error}", file=sys.stderr, flush=True)
            time.sleep(delay)
    raise RuntimeError(f"Failed after {retries} attempts: {last_error}") from last_error


def post_json(url: str, api_key: str, payload: dict[str, Any], timeout: float) -> tuple[bytes, str]:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    return open_request(request, timeout)


def download_audio(url: str, timeout: float) -> tuple[bytes, str]:
    request = urllib.request.Request(url, method="GET")
    body, content_type = open_request(request, timeout)
    extension = extension_for_content_type(content_type, extension_from_url(url) or "mp3")
    return body, extension


def open_request(request: urllib.request.Request, timeout: float) -> tuple[bytes, str]:
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            content_type = response.headers.get("Content-Type", "").split(";")[0].strip().lower()
            return response.read(), content_type
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {body}") from error


def extension_for_content_type(content_type: str, fallback: str) -> str:
    return CONTENT_TYPE_EXTENSIONS.get(content_type, fallback)


def extension_from_url(url: str) -> str | None:
    guessed, _ = mimetypes.guess_type(url.split("?", 1)[0])
    if not guessed:
        return None
    return CONTENT_TYPE_EXTENSIONS.get(guessed)


def find_audio_url(value: Any) -> str | None:
    if isinstance(value, dict):
        prioritized = ["url", "audio_url", "audioUrl"]
        for key in prioritized:
            candidate = value.get(key)
            if isinstance(candidate, str) and candidate.startswith(("http://", "https://")):
                return candidate
        for child in value.values():
            found = find_audio_url(child)
            if found:
                return found
    elif isinstance(value, list):
        for child in value:
            found = find_audio_url(child)
            if found:
                return found
    elif isinstance(value, str) and value.startswith(("http://", "https://")):
        return value
    return None


def find_base64_audio(value: Any) -> bytes | None:
    if isinstance(value, dict):
        for key in ("audio", "data", "audio_data", "audioData"):
            candidate = value.get(key)
            decoded = decode_base64_audio(candidate)
            if decoded:
                return decoded
        for child in value.values():
            found = find_base64_audio(child)
            if found:
                return found
    elif isinstance(value, list):
        for child in value:
            found = find_base64_audio(child)
            if found:
                return found
    return None


def decode_base64_audio(value: Any) -> bytes | None:
    if not isinstance(value, str) or len(value) < 100:
        return None
    if "," in value and value.lstrip().startswith("data:"):
        value = value.split(",", 1)[1]
    try:
        decoded = base64.b64decode(value, validate=True)
    except ValueError:
        return None
    return decoded if decoded.startswith((b"ID3", b"RIFF", b"\xff\xfb", b"\xff\xf3", b"\xff\xf2")) else None


if __name__ == "__main__":
    raise SystemExit(main())
