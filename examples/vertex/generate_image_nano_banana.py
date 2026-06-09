#!/usr/bin/env python3
"""Generate an image with Gemini 2.5 Flash Image ("nano-banana") on Vertex AI.

Usage:
    python3 generate_image_nano_banana.py "a watercolor fox reading a book"

Auth/config comes entirely from environment variables (see
docs/google-cloud-vertex-setup.md):
    GOOGLE_GENAI_USE_VERTEXAI=True
    GOOGLE_CLOUD_PROJECT=<your-project-id>
    GOOGLE_CLOUD_LOCATION=global

Run `gcloud auth application-default login` first so the SDK has credentials.
The script writes nothing sensitive and stores no keys.
"""
import os
import sys
from pathlib import Path

MODEL = "gemini-2.5-flash-image"  # "nano-banana"
OUT_DIR = Path(__file__).parent / "out"


def main() -> int:
    prompt = " ".join(sys.argv[1:]).strip() or "a friendly robot watering a plant, soft studio lighting"

    if os.environ.get("GOOGLE_GENAI_USE_VERTEXAI", "").lower() != "true":
        print("Set GOOGLE_GENAI_USE_VERTEXAI=True (see docs/google-cloud-vertex-setup.md).", file=sys.stderr)
        return 2
    if not os.environ.get("GOOGLE_CLOUD_PROJECT"):
        print("Set GOOGLE_CLOUD_PROJECT to your own GCP project ID.", file=sys.stderr)
        return 2

    try:
        from google import genai
    except ImportError:
        print("Missing dependency. Run: pip install -r examples/vertex/requirements.txt", file=sys.stderr)
        return 2

    # Reads GOOGLE_CLOUD_PROJECT / GOOGLE_CLOUD_LOCATION / GOOGLE_GENAI_USE_VERTEXAI from env.
    client = genai.Client()

    print(f"Generating with {MODEL} ...\n  prompt: {prompt}")
    try:
        response = client.models.generate_content(model=MODEL, contents=prompt)
    except Exception as exc:  # noqa: BLE001 — surface the real cause to the user
        print(f"\nGeneration failed: {exc}\n", file=sys.stderr)
        print("Common fixes: enable Vertex AI (gcloud services enable aiplatform.googleapis.com),", file=sys.stderr)
        print("re-run `gcloud auth application-default login`, confirm billing is attached.", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    saved = 0
    for candidate in response.candidates or []:
        for part in (candidate.content.parts or []):
            inline = getattr(part, "inline_data", None)
            if inline and inline.data:
                saved += 1
                ext = "png"
                if inline.mime_type and "/" in inline.mime_type:
                    ext = inline.mime_type.split("/")[-1]
                out = OUT_DIR / f"nano_banana_{saved}.{ext}"
                out.write_bytes(inline.data)
                print(f"  saved {out}  ({len(inline.data):,} bytes)")
            elif getattr(part, "text", None):
                print(f"  model note: {part.text}")

    if not saved:
        print("\nNo image returned. The model may have refused the prompt — try rephrasing.", file=sys.stderr)
        return 1
    print(f"\nDone. {saved} image(s) in {OUT_DIR}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
