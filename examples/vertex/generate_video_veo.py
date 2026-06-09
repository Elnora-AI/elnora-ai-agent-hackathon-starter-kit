#!/usr/bin/env python3
"""Generate a video with Veo 3 on Vertex AI.

Usage:
    python3 generate_video_veo.py "a timelapse of a city at dusk"

Veo on Vertex writes the rendered MP4 to a Google Cloud Storage bucket, so this
needs a REGIONAL location and an output bucket (see docs/google-cloud-vertex-setup.md):
    GOOGLE_GENAI_USE_VERTEXAI=True
    GOOGLE_CLOUD_PROJECT=<your-project-id>
    GOOGLE_CLOUD_LOCATION=us-central1
    VERTEX_OUTPUT_GCS_URI=gs://your-bucket/veo

The script writes nothing sensitive and stores no keys. Generation takes a few
minutes — that's normal for video.
"""
import os
import subprocess
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
    gcs_uri = os.environ.get("VERTEX_OUTPUT_GCS_URI")
    if not gcs_uri:
        print("Veo writes to GCS. Set VERTEX_OUTPUT_GCS_URI=gs://your-bucket/veo", file=sys.stderr)
        print("and GOOGLE_CLOUD_LOCATION to a region like us-central1.", file=sys.stderr)
        return 2

    try:
        from google import genai
        from google.genai.types import GenerateVideosConfig
    except ImportError:
        print("Missing dependency. Run: pip install -r examples/vertex/requirements.txt", file=sys.stderr)
        return 2

    client = genai.Client()  # reads project/location/Vertex flag from env

    print(f"Generating with {MODEL} ...\n  prompt: {prompt}\n  output: {gcs_uri}")
    try:
        operation = client.models.generate_videos(
            model=MODEL,
            prompt=prompt,
            config=GenerateVideosConfig(aspect_ratio="16:9", output_gcs_uri=gcs_uri),
        )
        waited = 0
        while not operation.done:
            time.sleep(POLL_SECONDS)
            waited += POLL_SECONDS
            print(f"  ... still rendering ({waited}s)")
            operation = client.operations.get(operation)
    except Exception as exc:  # noqa: BLE001
        print(f"\nGeneration failed: {exc}\n", file=sys.stderr)
        print("Common fixes: enable Vertex AI, use a regional location (us-central1),", file=sys.stderr)
        print("ensure the GCS bucket exists and billing is attached.", file=sys.stderr)
        return 1

    videos = getattr(operation.result, "generated_videos", None) or []
    if not videos:
        print("\nNo video returned — the prompt may have been refused. Try rephrasing.", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for i, gv in enumerate(videos, start=1):
        uri = getattr(getattr(gv, "video", None), "uri", None)
        print(f"  video {i}: {uri}")
        if uri and uri.startswith("gs://"):
            local = OUT_DIR / f"veo_{i}.mp4"
            # Best-effort local copy; ignore if gcloud/gsutil isn't on PATH.
            try:
                subprocess.run(["gcloud", "storage", "cp", uri, str(local)], check=True)
                print(f"    copied to {local}")
            except (subprocess.CalledProcessError, FileNotFoundError):
                print(f"    (couldn't copy locally — fetch it with: gcloud storage cp {uri} {local})")

    print(f"\nDone. Video(s) in {gcs_uri} (and {OUT_DIR}/ if the copy succeeded).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
