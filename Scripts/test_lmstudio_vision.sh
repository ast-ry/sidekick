#!/bin/zsh
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <model-id> <image-path> [base-url]"
  echo "Example: $0 google/gemma-3-4b-it ~/Desktop/capture.png http://127.0.0.1:1234/v1"
  exit 1
fi

MODEL_ID="$1"
IMAGE_PATH="$2"
BASE_URL="${3:-http://127.0.0.1:1234/v1}"

if [[ ! -f "$IMAGE_PATH" ]]; then
  echo "Image not found: $IMAGE_PATH"
  exit 1
fi

IMAGE_B64="$(base64 < "$IMAGE_PATH" | tr -d '\n')"
MIME_TYPE="image/png"
if [[ "$IMAGE_PATH" == *.jpg || "$IMAGE_PATH" == *.jpeg ]]; then
  MIME_TYPE="image/jpeg"
elif [[ "$IMAGE_PATH" == *.webp ]]; then
  MIME_TYPE="image/webp"
fi

echo "== GET /models =="
curl -s "${BASE_URL}/models"
echo
echo

echo "== POST /responses =="
curl -s "${BASE_URL}/responses" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL_ID}\",
    \"input\": [
      {
        \"role\": \"user\",
        \"content\": [
          {\"type\": \"input_text\", \"text\": \"この画像に何が表示されているか日本語で説明してください\"},
          {\"type\": \"input_image\", \"image_url\": \"data:${MIME_TYPE};base64,${IMAGE_B64}\"}
        ]
      }
    ]
  }"
echo
echo

echo "== POST /chat/completions =="
curl -s "${BASE_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL_ID}\",
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": [
          {\"type\": \"text\", \"text\": \"この画像に何が表示されているか日本語で説明してください\"},
          {\"type\": \"image_url\", \"image_url\": {\"url\": \"data:${MIME_TYPE};base64,${IMAGE_B64}\"}}
        ]
      }
    ]
  }"
echo
