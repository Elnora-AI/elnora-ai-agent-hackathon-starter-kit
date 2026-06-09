#!/usr/bin/env python3
"""Generate a voiceover (MP3) with Google Cloud Text-to-Speech.

Usage:
    python3 generate_voiceover_tts.py "Welcome to the hackathon."
    python3 generate_voiceover_tts.py "Tere tulemast" --language et-EE --voice et-EE-Standard-A

This is the universal "ADC token + REST" pattern from the setup guide, so it
needs NO pip dependencies — just the Python standard library plus the `gcloud`
CLI for the access token. The same shape calls any Google Cloud REST API.

Setup (see docs/google-cloud-vertex-setup.md):
    gcloud auth application-default login
    gcloud services enable texttospeech.googleapis.com --project YOUR_PROJECT_ID
    export GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID

Pick a voice/language from https://cloud.google.com/text-to-speech/docs/list-voices-and-types
(default: en-US-Neural2-F). Writes nothing sensitive and stores no keys.
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ENDPOINT = "https://texttospeech.googleapis.com/v1/text:synthesize"
OUT_DIR = Path(__file__).parent / "out"


def access_token() -> str:
    """Short-lived token minted from the user's ADC login."""
    return subprocess.run(
        ["gcloud", "auth", "application-default", "print-access-token"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Google Cloud Text-to-Speech voiceover")
    parser.add_argument("text", nargs="*", help="Text to narrate")
    parser.add_argument("--language", default="en-US", help="BCP-47 code, e.g. en-US, et-EE")
    parser.add_argument("--voice", default="en-US-Neural2-F", help="Voice name")
    parser.add_argument("--rate", type=float, default=1.0, help="Speaking rate (0.25–4.0)")
    args = parser.parse_args()

    if not 0.25 <= args.rate <= 4.0:
        print(f"--rate must be between 0.25 and 4.0 (got {args.rate}).", file=sys.stderr)
        return 2

    text = " ".join(args.text).strip() or "Welcome to the hackathon. Let's build something."
    project = os.environ.get("GOOGLE_CLOUD_PROJECT")
    if not project:
        print("Set GOOGLE_CLOUD_PROJECT to your own GCP project ID.", file=sys.stderr)
        return 2

    try:
        token = access_token()
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Couldn't get a token. Run: gcloud auth application-default login", file=sys.stderr)
        print("(and install the gcloud CLI — see docs/google-cloud-vertex-setup.md)", file=sys.stderr)
        return 2

    body = json.dumps({
        "input": {"text": text},
        "voice": {"languageCode": args.language, "name": args.voice},
        "audioConfig": {"audioEncoding": "MP3", "speakingRate": args.rate},
    }).encode()

    req = urllib.request.Request(
        ENDPOINT,
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "x-goog-user-project": project,  # which project gets billed/quota'd
            "Content-Type": "application/json",
        },
        method="POST",
    )

    print(f"Synthesizing ({args.voice}, {args.language}) ...\n  text: {text}")
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:500]
        print(f"\nTTS failed ({exc.code}): {detail}\n", file=sys.stderr)
        print("Common fixes: enable texttospeech.googleapis.com, confirm the voice name", file=sys.stderr)
        print("exists for the language, and that billing is attached to the project.", file=sys.stderr)
        return 1

    audio_b64 = data.get("audioContent")
    if not audio_b64:
        print("No audioContent in response.", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / "voiceover.mp3"
    out.write_bytes(base64.b64decode(audio_b64))
    print(f"\nDone. {out} ({out.stat().st_size:,} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
