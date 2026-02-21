#!/usr/bin/env python3
"""
Music recognition script for Noctalia plugin.
Captures system audio via pw-record and identifies via Shazam.

Usage: python recognize.py [--duration SECONDS]

Output (JSON):
  Success: {"status": "success", "title": "...", "artist": "...", "coverUrl": "...", "shazamUrl": "..."}
  No match: {"status": "no_match"}
  Error: {"status": "error", "error": "error_code", "message": "..."}

Error codes: no_pipewire, no_python310, no_network, capture_failed, recognition_failed
"""

import argparse
import asyncio
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

VENV_DIR = Path.home() / ".local/share/noctalia/plugins/music-recognizer/venv"
REQUIRED_PYTHON = (3, 10)


def send_notification(title: str, message: str, urgency: str = "normal") -> None:
    """Send desktop notification via notify-send as fallback."""
    try:
        subprocess.run(
            ["notify-send", "-u", urgency, "-a", "Music Recognizer", title, message],
            capture_output=True,
            timeout=5
        )
    except Exception:
        pass  # Notification is best-effort fallback


def output_json(data: dict) -> None:
    """Print JSON and exit."""
    print(json.dumps(data))
    sys.exit(0 if data.get("status") == "success" else 1)


def output_error(code: str, message: str, notify: bool = True) -> None:
    """Print error JSON and optionally send notification, then exit."""
    if notify:
        send_notification("Recognition Error", message, "normal")
    output_json({"status": "error", "error": code, "message": message})


def check_python_version() -> None:
    """Verify Python 3.10+."""
    if sys.version_info < REQUIRED_PYTHON:
        output_error(
            "no_python310",
            f"Python {REQUIRED_PYTHON[0]}.{REQUIRED_PYTHON[1]}+ required, got {sys.version_info.major}.{sys.version_info.minor}"
        )


def check_pipewire() -> None:
    """Verify pw-record is available."""
    if not shutil.which("pw-record"):
        output_error("no_pipewire", "pw-record not found. Install pipewire-audio-client-libraries")


def ensure_venv() -> Path:
    """Create venv and install shazamio if needed. Returns python path."""
    venv_python = VENV_DIR / "bin" / "python"

    if not venv_python.exists():
        VENV_DIR.mkdir(parents=True, exist_ok=True)
        subprocess.run([sys.executable, "-m", "venv", str(VENV_DIR)], check=True)
        # Install shazamio + audioop-lts (needed for Python 3.13+)
        subprocess.run(
            [str(venv_python), "-m", "pip", "install", "--quiet", "shazamio", "audioop-lts"],
            check=True
        )

    return venv_python


def get_monitor_node() -> str | None:
    """Get PipeWire default sink monitor node ID."""
    try:
        result = subprocess.run(
            ["pw-dump"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode != 0:
            return None

        nodes = json.loads(result.stdout)

        # Find default audio sink's monitor
        for node in nodes:
            if node.get("type") != "PipeWire:Interface:Node":
                continue
            props = node.get("info", {}).get("props", {})
            media_class = props.get("media.class", "")

            # Look for monitor sources
            if media_class == "Audio/Source" and ".monitor" in props.get("node.name", ""):
                return str(node.get("id"))

        # Fallback: find any audio sink and append .monitor
        for node in nodes:
            if node.get("type") != "PipeWire:Interface:Node":
                continue
            props = node.get("info", {}).get("props", {})
            media_class = props.get("media.class", "")

            if media_class == "Audio/Sink":
                return f"{node.get('id')}.monitor"

        return None
    except Exception:
        return None


def capture_audio(duration: int, output_path: str) -> bool:
    """Capture system audio via pw-record with timeout."""
    node_id = get_monitor_node()

    # pw-record doesn't have --duration, use timeout command
    pw_cmd = ["pw-record", "--rate", "44100", "--channels", "2", "--format", "s16"]
    if node_id:
        pw_cmd.extend(["--target", node_id])
    pw_cmd.append(output_path)

    # Wrap with timeout command
    cmd = ["timeout", str(duration)] + pw_cmd

    try:
        result = subprocess.run(cmd, capture_output=True, timeout=duration + 5)
        # timeout returns 124 on timeout (expected), 0 if finished early
        if result.returncode not in (0, 124):
            return False
        return os.path.exists(output_path) and os.path.getsize(output_path) > 1000
    except subprocess.TimeoutExpired:
        return False
    except Exception:
        return False


async def recognize_audio(audio_path: str, timeout: int = 30) -> dict | None:
    """Recognize audio using shazamio."""
    try:
        from shazamio import Shazam

        shazam = Shazam()
        result = await asyncio.wait_for(
            shazam.recognize(audio_path),
            timeout=timeout
        )

        if not result or not result.get("track"):
            return None

        track = result["track"]
        return {
            "status": "success",
            "title": track.get("title", "Unknown"),
            "artist": track.get("subtitle", "Unknown Artist"),
            "coverUrl": track.get("images", {}).get("coverart", ""),
            "shazamUrl": track.get("url", ""),
            "key": track.get("key", "")
        }
    except asyncio.TimeoutError:
        output_error("recognition_failed", "Recognition timeout")
    except ImportError:
        output_error("recognition_failed", "shazamio not installed")
    except Exception as e:
        output_error("recognition_failed", str(e))

    return None


def main():
    parser = argparse.ArgumentParser(description="Recognize music from system audio")
    parser.add_argument("--duration", type=int, default=5, help="Recording duration in seconds")
    args = parser.parse_args()

    # Pre-flight checks
    check_python_version()
    check_pipewire()

    # Ensure venv with shazamio
    try:
        venv_python = ensure_venv()
    except Exception as e:
        output_error("recognition_failed", f"Failed to setup venv: {e}")

    # If running from system Python, re-exec with venv Python
    if not str(sys.executable).startswith(str(VENV_DIR)):
        os.execv(str(venv_python), [str(venv_python), __file__, "--duration", str(args.duration)])

    # Capture audio
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        audio_path = tmp.name

    try:
        if not capture_audio(args.duration, audio_path):
            output_error("capture_failed", "Failed to capture system audio")

        # Recognize
        result = asyncio.run(recognize_audio(audio_path))

        if result:
            output_json(result)
        else:
            output_json({"status": "no_match"})
    finally:
        try:
            os.unlink(audio_path)
        except Exception:
            pass


if __name__ == "__main__":
    main()
