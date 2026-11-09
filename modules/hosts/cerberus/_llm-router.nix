# Cerberus local LLM rig: model storage mount and the llm-router catalogue.
_: {
  # Local LLM evaluation rig. One RTX 3090 Ti (24 GB) holds exactly one of
  # these at a time, so llama-swap fronts them all on the named loopback
  # endpoint llm:8000 and swaps the resident model based on each request's
  # "model" field.
  # See modules/services/llm-router.nix for why this is not oci-containers.
  #
  # VRAM budget is genuinely tight — weights alone are 17-21.6 GB of the
  # 24 GB, and Hyprland/browsers hold some of the rest. If a model OOMs on
  # load, lower --max-model-len first, then --gpu-memory-utilization.
  # Dedicated workspace + model repository: the 886 GB Btrfs partition on
  # the Samsung 970 EVO Plus, by UUID because the nvme0/nvme1 kernel names
  # swap between boots. Moving the ~151 GB HF model cache here takes it off
  # the root disk. Design and runbook:
  # ~/Vault/nix-issues/cerberus-nvme-workspace-and-model-storage-plan.md
  #
  # TODO(training-state): LoRA training stages ~16 GB of pinned weights per
  # run. Staging is a reflink (instant, no extra space) only on the same
  # btrfs filesystem as the model cache, so TRAINING_ROOT currently lives in
  # the git checkout at ~/Workspace/data/training-state, hidden through
  # .git/info/exclude. On the root ext4 disk the same copy took ~21 min and
  # 16 GB. Fix: add a subvolume (e.g. @training-state) on this device and
  # mount it outside the checkout, e.g. at
  # /home/warby/.local/state/nebula/training, mode 0700. It is the same
  # filesystem, so copy_file_range should still reflink across the two
  # mounts (FICLONE would not; verify by copying one cached weight and
  # checking that free space does not move). Then point TRAINING_ROOT there and
  # drop the exclude entry. A separate model-cache subvolume would take the
  # cache out of the checkout too. Measurements:
  # docs/operations/lora-klein-sprite-pilot.md on feat/klein-sprite-pilot.
  fileSystems."/home/warby/Workspace" = {
    device = "/dev/disk/by-uuid/016ecaf4-f6fd-4457-aa2e-3dcebce80832";
    fsType = "btrfs";
    options = [
      "subvol=@workspace"
      "compress=zstd:1"
      "noatime"
      "nofail"
    ];
  };

  services.infra.llmRouter = {
    enable = true;
    # Fast NVMe model cache on Samsung 970 EVO Plus (nvme0n1p6 @workspace)
    hfCacheDir = "/home/warby/Workspace/data/model-cache/huggingface";
    models = {
      # Validated on this 3090 Ti through Maya's pinned vLLM 0.27.1 image.
      # This needs CPU offload because the NVFP4 checkpoint plus its runtime
      # working set does not fit beside the desktop entirely in VRAM.
      gemma4 = {
        backend = "vllm";
        image = "vllm/vllm-openai:v0.27.1";
        model = "nvidia/Gemma-4-26B-A4B-NVFP4";
        extraArgs = [
          "--max-model-len 4096"
          "--gpu-memory-utilization 0.78"
          "--max-num-seqs 1"
          "--cpu-offload-gb 6"
          "--language-model-only"
          "--moe-backend marlin"
          "--kv-cache-dtype bfloat16"
          "--reasoning-parser gemma4"
          "--tool-call-parser gemma4"
          "--enable-auto-tool-choice"
          "--trust-remote-code"
          "--hf-overrides '{\"architectures\":[\"Gemma4ForCausalLM\"],\"text_config\":{\"allow_global_per_layer_attribute_access\":true,\"global_head_dim\":512,\"num_global_key_value_heads\":2}}'"
        ];
      };

      # The only vision model here. Small on purpose: at ~5 GB it loads in
      # seconds rather than the tens of seconds a 30B swap costs, which
      # matters because a describe call is a single request rather than a
      # conversation, and the caller pays the load every time the router
      # has swapped away. gemma4 is multimodal on paper but is served
      # --language-model-only, so it cannot cover this.
      qwen25vl = {
        backend = "llamacpp";
        model = "ggml-org/Qwen2.5-VL-7B-Instruct-GGUF";
        file = "Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf";
        mmproj = "mmproj-Qwen2.5-VL-7B-Instruct-f16.gguf";
        extraArgs = [
          "-c 8192"
          "-ngl 99"
        ];
      };

      # NVFP4 (21.6 GB) does not fit: only ~19.6 GB is free with the
      # desktop running, and Ampere has no FP4 tensor cores so the NVFP4
      # checkpoint never shrinks below its safetensors size anyway. The
      # smallest usable GGUF is Q4_0 at 18.9 GB, which is still tight — if
      # it OOMs, drop -ngl below 99 to spill a few layers into system RAM
      # (there is 125 GB of it). vLLM cannot do that; llama.cpp can.
      nemotron = {
        backend = "llamacpp";
        model = "ggml-org/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF";
        file = "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-Q4_0.gguf";
        extraArgs = [
          "-ngl 99"
          # 8192 is the practical ceiling: measured 22.3 GB resident at this
          # setting, leaving 1.8 GB spare on a 24 GB card that is also
          # driving the desktop. More context does not fit.
          #
          # CONSEQUENCE: this model cannot drive the DeepSeek Harness. dsh
          # sends 10,280 tokens of system prompt and tool definitions before
          # the first user message, so it errors with
          # CONTEXT_WINDOW_EXCEEDED here (verified). Nemotron is usable for
          # direct chat only; use qwen38 or muse-glimmer for agent work.
          "-c 8192"
          # This model reasons hard — a one-sentence greeting cost 818
          # completion tokens, ~2.9 KB of it in reasoning_content. Clients
          # capping max_tokens near 500 get an empty `content` and
          # finish_reason "length", which looks like a failure but is the
          # budget being spent mid-thought.
          "--reasoning-format"
          "auto"
        ];
      };

      # The separately validated NVFP4 fast path. Keep the shorter
      # `nemotron` GGUF alias above as the lower-risk llama.cpp fallback.
      "nemotron-3.5-lightning-nvfp4" = {
        backend = "vllm";
        image = "vllm/vllm-openai:v0.27.1";
        model = "nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4";
        extraArgs = [
          "--max-model-len 2048"
          "--gpu-memory-utilization 0.80"
          "--max-num-seqs 1"
          "--cpu-offload-gb 2.0"
          "--enforce-eager"
          "--no-enable-prefix-caching"
          "--max-num-batched-tokens 2048"
          "--kv-cache-memory 268435456"
          "--attention-backend TRITON_ATTN"
          "--kv-cache-dtype bfloat16"
          "--moe-backend marlin"
          "--linear-backend marlin"
          "--quantization modelopt_fp4"
          "--mamba-backend flashinfer"
          "--mamba-cache-mode align"
          "--mamba-ssu-algorithm simple"
          "--reasoning-parser nemotron_v3"
          "--tool-call-parser qwen3_coder"
          "--enable-auto-tool-choice"
        ];
      };

      # Muse-Glimmer ships no vLLM-loadable 24 GB checkpoint: the base repo is
      # BF16 (59.6 GB) and the NVFP4 conversions are 23.4 GB. The only variant
      # that fits is Meta's own K-Quant GGUF (16.8 GB), and GGUF is where
      # llama.cpp is the right engine rather than a compromise — vLLM's GGUF
      # support is experimental and ignores the mmproj/draft files entirely.
      muse-glimmer = {
        backend = "llamacpp";
        model = "meta-models/Muse-Glimmer-30B-GGUF";
        file = "Muse-Glimmer-30B-KQuant-17GB-Q4_K_M.gguf";
        extraArgs = [
          "-ngl 99"
          "-c 16384"
        ];
      };

      # Preserve the public alias used by the earlier Maya CUDA matrix.
      # It resolves to the same cached Meta GGUF as `muse-glimmer`.
      muse-glimmer-30b = {
        backend = "llamacpp";
        model = "meta-models/Muse-Glimmer-30B-GGUF";
        file = "Muse-Glimmer-30B-KQuant-17GB-Q4_K_M.gguf";
        extraArgs = [
          "-ngl 99"
          "-c 4096"
          "--flash-attn on"
          "--fit on"
          "--fit-target 1536"
          "--top-k 64"
          "--jinja"
          "--reasoning-format deepseek"
          "--chat-template-kwargs '{\"reasoning_strength\":\"low\"}'"
          "--no-mmproj"
          "--no-webui"
        ];
      };

      # Exercise Qwen3.8 through SGLang while preserving the public qwen38
      # alias already stored in Maya connection profiles. SGLang 0.5.18
      # cannot load Qwen3.5-family GGUF yet, and AWQ quantizes the 96-wide
      # GDN projections into a shape its Marlin repacker rejects. This
      # AutoRound checkpoint deliberately leaves those projections in BF16.
      #
      # The checkpoint is multimodal, but the vision tower is dead weight for
      # Maya chat. Overriding language_model_only skips it and saves ~0.6 GB.
      # The resulting measured 4K footprint is ~17.0 GB weights + 0.29 GB
      # Mamba state + 0.26 GB KV, leaving ~0.5 GB after cached Triton kernels
      # on this live desktop. 4K also admits the UI's 2048-token preset.
      qwen38 = {
        backend = "sglang";
        model = "Frozenlock/Qwen3.8-27B-int4-AutoRound";
        extraArgs = [
          "--quantization auto-round"
          "--json-model-override-args '{\"language_model_only\":true}'"
          "--context-length 4096"
          "--max-total-tokens 4096"
          "--max-running-requests 1"
          "--mem-fraction-static 0.99"
          "--chunked-prefill-size 512"
          "--attention-backend triton"
          "--cuda-graph-backend-decode disabled"
          "--cuda-graph-backend-prefill disabled"
          "--disable-overlap-schedule"
          "--trust-remote-code"
          "--reasoning-parser qwen3"
          "--tool-call-parser qwen3_coder"
          "--mamba-radix-cache-strategy no_buffer"
          "--max-mamba-cache-size 3"
          "--mamba-ssm-dtype bfloat16"
          "--mamba-full-memory-ratio 1.0"
        ];
      };

      # Known-good rollback and long-context path for the same checkpoint.
      qwen38-llamacpp = {
        backend = "llamacpp";
        model = "unsloth/Qwen3.8-27B-GGUF";
        file = "Qwen3.8-27B-UD-Q4_K_M.gguf";
        extraArgs = [
          "-ngl 99"
          "-c 32768"
        ];
      };

      # The validated official FP8/vLLM variant. Keep it available beside
      # the SGLang qwen38 alias for engine-to-engine comparisons.
      "qwen3.8-27b-fp8" = {
        backend = "vllm";
        image = "vllm/vllm-openai:v0.27.1";
        model = "Qwen/Qwen3.8-27B-FP8";
        extraArgs = [
          "--max-model-len 4096"
          "--gpu-memory-utilization 0.75"
          "--max-num-seqs 1"
          "--cpu-offload-gb 14"
          "--language-model-only"
        ];
      };
    };
  };
}
