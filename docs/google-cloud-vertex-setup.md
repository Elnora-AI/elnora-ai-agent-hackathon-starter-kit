# Google Cloud + Vertex AI setup (image, video, voiceover + the rest)

**Set this up once and you unlock Google Cloud's whole AI surface** — image
generation (Gemini 2.5 Flash Image, a.k.a. "nano-banana"), video (Veo 3),
voiceover (Text-to-Speech), Gemini text, Imagen, Speech-to-Text, embeddings,
translation, and more. It's all the **same one-time auth** (`gcloud` +
Application Default Credentials); after that, every model is a different
endpoint or model ID, not a new setup.

The auth pattern here — ADC plus a short-lived access token — is the standard,
Google-documented way to call these APIs; nothing in this repo is specific to
any one account.

> **For agents:** this is a hand-holding guide. The human almost certainly has
> never touched `gcloud`. Run each command *for* them where you can, read back
> the output, and stop at the two steps only they can do (creating/picking a
> billing-enabled project, and the browser auth). Never invent a project ID —
> use the one they give you. Everything here uses **their own** GCP project; the
> starter kit ships no Google credentials. Once §3 (ADC) is done, you can reach
> **any** Google Cloud AI API with the universal recipe below — you are not
> limited to the example scripts.

---

## What you can do once this works

| Capability | Model / endpoint | How |
|------------|------------------|-----|
| Image generation + editing ("nano-banana") | `gemini-2.5-flash-image` | SDK — [`examples/vertex/generate_image_nano_banana.py`](../examples/vertex/generate_image_nano_banana.py) |
| Text/image → video ("Veo 3") | `veo-3.0-generate-001` | SDK — [`examples/vertex/generate_video_veo.py`](../examples/vertex/generate_video_veo.py) |
| Voiceover / narration (Text-to-Speech) | `texttospeech.googleapis.com` | REST + ADC token — [`examples/vertex/generate_voiceover_tts.py`](../examples/vertex/generate_voiceover_tts.py) |
| Gemini text / chat / vision | `gemini-2.5-flash`, `gemini-2.5-pro` | SDK `client.models.generate_content` |
| Imagen (photoreal images) | `imagen-4.0-generate-001` | SDK `client.models.generate_images` |
| Speech-to-Text (transcription) | `speech.googleapis.com` | REST + ADC token (same recipe as TTS) |
| Text embeddings | `text-embedding-005` | SDK `client.models.embed_content` |
| Translation | `translate.googleapis.com` | REST + ADC token |

The example scripts cover the first three. Everything else is reachable with the
**universal recipe** (see "Call any Google Cloud AI API" below) — Vertex/Google
Cloud is a large catalogue and the same credentials open all of it.

---

## Prerequisites (human does these)

1. **A Google account** and access to <https://console.cloud.google.com>.
2. **A Google Cloud project with billing enabled.** Vertex AI will not run
   without a billing account attached, even when you're spending free credits.
   - New project: <https://console.cloud.google.com/projectcreate>
   - Note the **Project ID** (not the display name) — e.g. `my-hackathon-1234`.
   - Hackathon participants: if you were given GCP credits, redeem them and
     attach the billing account to this project.

Give the agent your **Project ID** when asked.

---

## Step 1 — Install the gcloud CLI

The agent can run these. Verify first: `gcloud --version`.

**macOS** (Homebrew is cleanest):
```bash
brew install --cask google-cloud-sdk
```
No Homebrew? Use the interactive installer:
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL    # reload shell so `gcloud` is on PATH
```

**Windows (PowerShell):**
```powershell
(New-Object Net.WebClient).DownloadFile("https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe", "$env:Temp\GoogleCloudSDKInstaller.exe")
& "$env:Temp\GoogleCloudSDKInstaller.exe"
```

**Linux:**
```bash
curl https://sdk.cloud.google.com | bash && exec -l $SHELL
```

Confirm:
```bash
gcloud --version
```

---

## Step 2 — Log in and select the project

**Human step (browser):** authenticate the CLI.
```bash
gcloud auth login
```

Point gcloud at the project (use the Project ID from prerequisites):
```bash
gcloud config set project YOUR_PROJECT_ID
```

---

## Step 3 — Application Default Credentials (ADC)

The SDK authenticates via ADC, *not* the `gcloud auth login` session above.
This is a second browser login — it's expected.

**Human step (browser):**
```bash
gcloud auth application-default login
```

Set the quota/billing project for ADC so the SDK knows who to bill:
```bash
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
```

> Service-account JSON key files also work (set `GOOGLE_APPLICATION_CREDENTIALS`
> to the file path), but for a laptop, ADC via browser login is simpler and
> there's no key file to leak. Prefer ADC unless you're deploying to a server.

---

## Step 4 — Enable the APIs you want

Vertex AI (image, video, Gemini, Imagen, embeddings) is one API. Voiceover,
transcription, and translation are separate APIs — enable whichever you'll use.
Enabling one you don't end up calling costs nothing.

```bash
# Vertex AI — image (nano-banana), video (Veo), Gemini, Imagen, embeddings
gcloud services enable aiplatform.googleapis.com --project YOUR_PROJECT_ID

# Voiceover (Text-to-Speech) — used by the voiceover example
gcloud services enable texttospeech.googleapis.com --project YOUR_PROJECT_ID

# Optional extras — enable on demand
gcloud services enable speech.googleapis.com     --project YOUR_PROJECT_ID  # speech-to-text
gcloud services enable translate.googleapis.com  --project YOUR_PROJECT_ID  # translation
```

Each can take a minute the first time.

---

## Step 5 — Environment variables

Copy these into your `.env` (already scaffolded in `.env.template`), or export
them in the shell. The example scripts read them.

```bash
export GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID
export GOOGLE_CLOUD_LOCATION=global      # Gemini/nano-banana; Veo needs a region (see below)
export GOOGLE_GENAI_USE_VERTEXAI=True
```

- **nano-banana (image):** `global` is fine.
- **Veo 3 (video):** use a regional location such as `us-central1`, and provide
  a **GCS bucket** for the output:
  ```bash
  export GOOGLE_CLOUD_LOCATION=us-central1
  export VERTEX_OUTPUT_GCS_URI=gs://your-bucket/veo
  # one-time: create the bucket
  gcloud storage buckets create gs://your-bucket --location=us-central1
  ```

---

## Step 6 — Install the SDK and run the examples

```bash
python3 -m pip install -r examples/vertex/requirements.txt

# image (nano-banana)
python3 examples/vertex/generate_image_nano_banana.py "a watercolor fox reading a book"

# video (Veo 3) — needs GOOGLE_CLOUD_LOCATION=us-central1 + VERTEX_OUTPUT_GCS_URI
python3 examples/vertex/generate_video_veo.py "a timelapse of a city at dusk"

# voiceover (Text-to-Speech) — needs texttospeech.googleapis.com enabled (Step 4)
python3 examples/vertex/generate_voiceover_tts.py "Welcome to the hackathon."
```

A PNG, an MP4 (Veo), and an MP3 (voiceover) land in `examples/vertex/out/`. The
voiceover script uses only the Python standard library — no pip install needed
for that one.

---

## Call any Google Cloud AI API (the universal recipe)

The example scripts are starting points, not the boundary. Once Step 3 (ADC) is
done, **any** Google Cloud REST API is reachable with a short-lived access token
— this is exactly how the voiceover example works, and it generalizes to
Speech-to-Text, Translation, Document AI, and the rest.

```bash
# A token good for ~1 hour, minted from your ADC login:
TOKEN=$(gcloud auth application-default print-access-token)

# Then call any API: Bearer token + your project as the quota header.
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: YOUR_PROJECT_ID" \
  -H "Content-Type: application/json" \
  "https://texttospeech.googleapis.com/v1/text:synthesize" \
  -d '{
        "input": {"text": "Hello from Google Cloud"},
        "voice": {"languageCode": "en-US", "name": "en-US-Neural2-F"},
        "audioConfig": {"audioEncoding": "MP3"}
      }'
```

The two load-bearing headers for any Google Cloud API are the **Bearer token**
and **`x-goog-user-project`** (which project gets billed/quota'd). Swap the URL
and JSON body for whatever service you need — the
[API reference](https://cloud.google.com/apis) lists endpoints for every
service. For Vertex AI specifically, the `google-genai` SDK (used by the image
and video examples) is usually nicer than raw REST, but the token recipe always
works as a fallback.

> **For agents:** when a participant wants a Google Cloud capability the example
> scripts don't cover, don't tell them it's unsupported — mint a token with the
> command above and call the right REST endpoint, or use the `google-genai` SDK
> for Vertex models. The setup is identical; only the endpoint changes.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `PermissionDenied` / `aiplatform.googleapis.com ... not enabled` | Re-run Step 4; wait a minute; confirm the right project with `gcloud config get-value project`. |
| `Reauthentication required` / `invalid_grant` | Re-run `gcloud auth application-default login`. |
| `403 ... billing` | Attach a billing account to the project in the console. |
| Veo: `output_gcs_uri` error or empty result | Veo writes to GCS. Set `VERTEX_OUTPUT_GCS_URI` and use a regional `GOOGLE_CLOUD_LOCATION` (e.g. `us-central1`). |
| Voiceover: `texttospeech ... not enabled` / `403` | Enable it: `gcloud services enable texttospeech.googleapis.com`. |
| Voiceover: `SERVICE_DISABLED` for `x-goog-user-project` | The project in the header must match a real, billing-enabled project you own. |
| Model `not found` / `404` | Model IDs evolve. Check current IDs in [Model Garden](https://console.cloud.google.com/vertex-ai/model-garden); newer variants (e.g. `veo-3.1-generate-001`, Gemini 3 image) may be available. |
| Quota exceeded | These are preview models with low default quotas — request more in the console or retry later. |

## Security notes

- The example scripts never write secrets. ADC tokens live in
  `~/.config/gcloud/` (managed by gcloud), not in this repo.
- If you use a service-account key, keep the `.json` out of git (the repo's
  `.gitignore` already covers `credentials*.json` / `*.json` keys — verify
  before committing) and reference it only by path via
  `GOOGLE_APPLICATION_CREDENTIALS`.
- All nano-banana output carries an invisible **SynthID** watermark marking it
  AI-generated.
