#!/usr/bin/env python3
"""Generate a video with Veo 3 on Vertex AI.

Usage:
    python3 generate_video_veo.py "a timelapse of a city at dusk"

Veo returns the rendered MP4 inline; this script saves it to out/. No GCS bucket
needed. Veo isn't available on `global`, so use a REGIONAL location:
    GOOGLE_GENAI_USE_VERTEXAI=True
    GOOGLE_CLOUD_PROJECT=<your-project-id>
    GOOGLE_CLOUD_LOCATION=us-central1

The script writes nothing sensitive and stores no keys. Generation takes a few
minutes — that's normal for video.
"""
import os
import sys
import time
from pathlib import Path

MODEL = "veo-3.0-generate-001"  # "Veo 3"; newer: veo-3.1-generate-001
OUT_DIR = Path(__file__).parent / "out"
POLL_SECONDS = 15


def main() -> int:
    prompt = " ".join(sys.argv[1:]).strip() or "a slow cinematic pan over snow-capped mountains at sunrise"

    if os.environ.get("GOOGLE_GENAI_USE_VERTEXAI", "").lower() != "true":
        print("Set GOOGLE_GENAI_USE_VERTEXAI=True (see docs/google-cloud-vertex-setup.md).", file=sys.stderr)
        return 2
    if not os.environ.get("GOOGLE_CLOUD_PROJECT"):
        print("Set GOOGLE_CLOUD_PROJECT to your own GCP project ID.", file=sys.stderr)
        return 2

    try:
        from google import genai
        from google.genai.types import GenerateVideosConfig
    except ImportError:
        print("Missing dependency. Run: pip install -r examples/vertex/requirements.txt", file=sys.stderr)
        return 2

    client = genai.Client()  # reads project/location/Vertex flag from env

    print(f"Generating with {MODEL} ...\n  prompt: {prompt}")
    try:
        operation = client.models.generate_videos(
            model=MODEL,
            prompt=prompt,
            config=GenerateVideosConfig(aspect_ratio="16:9"),
        )
        waited = 0
        while not operation.done:
            time.sleep(POLL_SECONDS)
            waited += POLL_SECONDS
            print(f"  ... still rendering ({waited}s)")
            operation = client.operations.get(operation)
    except Exception as exc:  # noqa: BLE001
        print(f"\nGeneration failed: {exc}\n", file=sys.stderr)
        print("Common fixes: enable Vertex AI, use a regional location (us-central1,", file=sys.stderr)
        print("not global), and make sure billing is attached to the project.", file=sys.stderr)
        return 1

    videos = getattr(operation.response, "generated_videos", None) or []
    if not videos:
        print("\nNo video returned — the prompt may have been refused. Try rephrasing.", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for i, gv in enumerate(videos, start=1):
        local = OUT_DIR / f"veo_{i}.mp4"
        gv.video.save(str(local))
        print(f"  video {i}: saved to {local}")

    print(f"\nDone. Video(s) in {OUT_DIR}/.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
