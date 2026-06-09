# Google Cloud AI examples — image, video, voiceover

Minimal, runnable scripts. The image and video ones use the `google-genai` SDK
(Vertex AI); the voiceover one uses the standard-library "ADC token + REST"
pattern (no pip deps) that works for **any** Google Cloud API.

| Script | What it does | Model / endpoint | Deps |
|--------|--------------|------------------|------|
| `generate_image_nano_banana.py` | Text → image (and editing) | `gemini-2.5-flash-image` | `google-genai` |
| `generate_video_veo.py` | Text → video | `veo-3.0-generate-001` | `google-genai` |
| `generate_voiceover_tts.py` | Text → narration (MP3) | `texttospeech.googleapis.com` | stdlib only |

These three are starting points, not the limit. The same one-time setup unlocks
Gemini text, Imagen, Speech-to-Text, embeddings, translation, and more — see the
"Call any Google Cloud AI API" recipe in
[`../../docs/google-cloud-vertex-setup.md`](../../docs/google-cloud-vertex-setup.md).

## Quick start

1. Do the one-time setup in [`../../docs/google-cloud-vertex-setup.md`](../../docs/google-cloud-vertex-setup.md)
   (install gcloud, `application-default login`, enable Vertex AI, set env vars).
   **New to this? Ask the agent** — it can run most of it for you.
2. Install deps:
   ```bash
   python3 -m pip install -r requirements.txt
   ```
3. Generate:
   ```bash
   python3 generate_image_nano_banana.py "a watercolor fox reading a book"
   python3 generate_video_veo.py "a timelapse of a city at dusk"
   python3 generate_voiceover_tts.py "Welcome to the hackathon."
   ```

Output lands in `out/` (gitignored). Image gen needs `GOOGLE_CLOUD_LOCATION=global`;
Veo needs a region (`us-central1`) plus a `VERTEX_OUTPUT_GCS_URI` bucket;
voiceover needs `texttospeech.googleapis.com` enabled and only
`GOOGLE_CLOUD_PROJECT` set.

## Notes

- These use **your own** GCP project. Nothing here ships Google credentials.
- Model IDs change. If you hit a `404`, check
  [Model Garden](https://console.cloud.google.com/vertex-ai/model-garden) for
  the current ID (e.g. `veo-3.1-generate-001`).
- nano-banana images carry an invisible SynthID watermark.
