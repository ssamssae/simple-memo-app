# Stage1 artifact and license record

Checked on 2026-07-16 KST. This is an engineering inventory, not legal advice.
No model weights are committed to this branch; `models/` and `results/` are
git-ignored.

## EmbeddingGemma seq512

- Model card: <https://ai.google.dev/gemma/docs/embeddinggemma/model_card>
- Terms: <https://ai.google.dev/gemma/terms>
- Artifact repository: <https://huggingface.co/litert-community/embeddinggemma-300m>
- Pinned repository revision: `870cbe05ef460385363c6b574c851ae5d8989ce3`
- License/terms label: Gemma Terms of Use; the repository is gated.
- Acceptance method: an operator must review and accept the Gemma terms on the
  model provider before obtaining the files. `prepare_models.sh` deliberately
  has no token parameter and never accepts terms or downloads this model. It
  only accepts already-obtained local files when
  `--gemma-terms-accepted` is supplied, checks their pinned SHA256 values, and
  records a local attestation alongside the ignored files.
- Redistribution/notice review remains a separate gate. This spike does not
  bundle or redistribute the model.

Runtime wrapper:

- `flutter_gemma` 1.0.1 and `flutter_gemma_embeddings` 1.0.1.
- Wrapper source: <https://github.com/DenisovAV/flutter_gemma>
- Wrapper license: MIT.

## multilingual-e5-small ONNX

- Model card/repository: <https://huggingface.co/intfloat/multilingual-e5-small>
- Pinned revision: `614241f622f53c4eeff9890bdc4f31cfecc418b3`
- Model-card license: MIT.
- The published qint8 artifact is AVX512/VNNI-specific, so this mobile spike
  intentionally pins the generic `onnx/model.onnx` artifact instead of
  presenting that x86 quantization as ARM-compatible.

## paraphrase-multilingual-MiniLM-L12-v2 ONNX

- Model card/repository:
  <https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2>
- Pinned revision: `e8f8c211226b894fcb81acc59f3b34ba3efd5f42`
- Model-card license: Apache-2.0.
- The spike pins the repository's published `model_qint8_arm64.onnx` artifact.

ONNX/tokenizer runtime:

- `flutter_onnxruntime` 1.8.2, MIT:
  <https://github.com/masicai/flutter_onnxruntime>
- Microsoft ONNX Runtime mobile documentation:
  <https://onnxruntime.ai/docs/get-started/with-mobile.html>
- Microsoft ONNX Runtime license, MIT:
  <https://github.com/microsoft/onnxruntime/blob/main/LICENSE>
- `dart_sentencepiece_tokenizer` 1.3.2, MIT:
  <https://pub.dev/packages/dart_sentencepiece_tokenizer>
- `unorm_dart` 0.3.2, MIT:
  <https://pub.dev/packages/unorm_dart>

The community Flutter binding is not an official Microsoft Flutter binding.
The published XLM-R tokenizer JSON uses a precompiled SentencePiece charsmap
that the selected pure-Dart tokenizer does not consume directly. The spike
therefore pins the shared binary SentencePiece model, applies the documented
`nmt_nfkc` compatibility mapping, remaps raw SentencePiece IDs to XLM-R IDs,
and checks seven token-ID fixtures produced by each pinned upstream tokenizer.
It also compares a SHA256 over the exact 102 benchmark inputs (two queries plus
the 100-memo corpus) with each pinned upstream tokenizer's captured output.
The spike keeps tokenizer, mean-pooling, L2 normalization, model revision, and
engine dimension explicit so the later device leg can detect integration drift
rather than silently mixing vectors.
