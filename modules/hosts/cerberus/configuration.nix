_: {
  flake.nixosModules.cerberus =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      chromiumBrowsers = import "${inputs.self}/modules/_chromium-browsers.nix" { inherit lib; };
      inherit (chromiumBrowsers)
        chromiumStandardExtensions
        heliumBundledExtensionsToRemove
        ;
    in
    {
      imports = [
        inputs.self.nixosModules.cerberusHardware
        "${inputs.self}/modules/_features/ssh-keys.nix"
        inputs.self.nixosModules.nvidia
        inputs.self.nixosModules.gaming
        inputs.self.nixosModules.dev
        inputs.self.nixosModules.agenixHost
        inputs.self.nixosModules.chromiumPolicy
        "${inputs.self}/modules/_features/audio.nix"
        "${inputs.self}/modules/_features/sunshine.nix"
        "${inputs.self}/modules/_features/file-sharing.nix"
        "${inputs.self}/modules/_features/syncthing.nix"
        "${inputs.self}/modules/_features/hardware-tuning.nix"
        "${inputs.self}/modules/_features/waydroid-feh.nix"
        "${inputs.self}/modules/_features/pokeforce.nix"
        "${inputs.self}/modules/_features/fhs-compat.nix"
        "${inputs.self}/modules/_features/security.nix"
        "${inputs.self}/modules/_features/users.nix"
        "${inputs.self}/modules/_features/firefox-policy.nix"
        inputs.agenix.nixosModules.default
        inputs.self.nixosModules.infraContract
        inputs.self.nixosModules.infraSecrets
        inputs.self.nixosModules.infraIngress
        inputs.self.nixosModules.profileInfraSpine
        inputs.self.nixosModules.profileDemoCerberus
        inputs.self.nixosModules.postgresInfra
        inputs.self.nixosModules.valkeyInfra
        inputs.self.nixosModules.openbaoInfra
        inputs.self.nixosModules.traefikInfra
        inputs.self.nixosModules.authentikInfra
        inputs.self.nixosModules.pyloadInfra
        inputs.self.nixosModules.mayaWorkerInfra
        inputs.self.nixosModules.agenixInfra
        inputs.self.nixosModules.llmRouter
        inputs.self.nixosModules.deepseekHarnessInfra
      ];

      networking.hostName = config.host.hostName;

      nixpkgs.overlays = [
        inputs.nix-cachyos-kernel.overlays.pinned
        (import "${inputs.self}/modules/_features/overlays/cursor.nix")
        (_final: prev: {
          # oci-cli 3.88.0 declares setuptools <81, but nixpkgs supplies 82.
          # The wheel builds successfully; only the metadata check is stale.
          oci-cli = prev.oci-cli.overridePythonAttrs (_old: {
            dontCheckRuntimeDeps = true;
          });
        })
      ];

      host = {
        hostName = "cerberus-nix";
        isDesktop = true;
        class = "desktop";
        bar = "noctalia";
        desktop = "hyprland";
        greeter = "sddm";
        gpuType = "nvidia";
        theme = "kanagawa-dragon";
        workload = "default";
        gamehacking.enable = true;
        citraAgent = {
          enable = true;
          gameRoot = "/home/warby/Games/roms/3ds";
        };
        iw4x.enable = true;
        pokeforce.enable = true;
        scbw.enable = true;
        remoteGaming.enable = true;
        syncthing.enable = true;
        wallpaper = "${inputs.wallpapers.packages.x86_64-linux.default}/share/wallpapers/kanagawa-dragon/3895e.jpg";
        mainMonitor = {
          name = "desc:Dell Inc. Dell S2716DG #ASPYT+r5vCzd";
          width = "2560";
          height = "1440";
          refresh = "144";
        };
        secondaryMonitor = {
          name = "desc:Dell Inc. DELL P2422H 46Z5YB3";
          width = "1920";
          height = "1080";
          refresh = "60";
        };
      };

      # TODO(unsolved): the demo spine (Postgres, Valkey, OpenBao, Traefik, Authentik
      # + pyLoad + mayaWorker) collides with the Docker dev stack this workstation
      # already runs, so every spine service lost its port and retried forever:
      # valkey 22474 restarts (:6379 held by a Docker valkey), pyload 9741 (missing
      # /srv/config, re-pulling its image each attempt), authentik x3 at 1162 each
      # (Postgres role auth), maya-bot 11534. Turning the flag off is the fix until
      # the shared-developer services are settled — see docs/infra/README.md.
      # To re-enable: one Postgres and one Valkey must own :5432/:6379 with no Docker
      # container publishing them, and Authentik needs a real key via agenix (its
      # current one is literally "demo-...-replace-with-agenix-before-prod").
      infra.demo.enable = false;

      # Local LLM evaluation rig. One RTX 3090 Ti (24 GB) holds exactly one of
      # these at a time, so llama-swap fronts them all on the named loopback
      # endpoint llm:8000 and swaps the resident model based on each request's
      # "model" field.
      # See modules/services/llm-router.nix for why this is not oci-containers.
      #
      # VRAM budget is genuinely tight — weights alone are 17-21.6 GB of the
      # 24 GB, and Hyprland/browsers hold some of the rest. If a model OOMs on
      # load, lower --max-model-len first, then --gpu-memory-utilization.
      services.infra.llmRouter = {
        enable = true;
        # Reuse the already validated/downloaded CUDA matrix cache rather than
        # downloading another copy of the vLLM checkpoints into ~/.cache.
        hfCacheDir = "/home/warby/Workspace-git/maya-unified/data/model-cache/huggingface";
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

      # Agent harness driving the router above; see /etc/deepseek-harness/env.
      services.infra.deepseek-harness.enable = true;

      # Developer Lamia Browser Adapter. Nixpkgs Chromium resolves native hosts
      # through this system registry rather than Chrome's per-user registry.
      environment.etc."chromium/native-messaging-hosts/org.lamia.browser.json".text = builtins.toJSON {
        name = "org.lamia.browser";
        description = "Lamia Browser Adapter development host";
        path = "/home/warby/Workspace-git/maya-unified/scripts/lamia-browser-host-dev.sh";
        type = "stdio";
        allowed_origins = [ "chrome-extension://mlpcnheempoikdefoabobmilgdnicdlm/" ];
      };

      # Chromium-based browser policies (Helium, Chromium, etc.)
      # flags.vaapi here is metadata only; launch flags come from HM *-flags.conf
      # with vaapiMode = "nvidia" (see modules/home.nix + gpuType in cerberus HM).
      chromiumPolicies = {
        enable = true;
        browsers = {
          chrome = {
            enable = true;
            policyPath = "opt/chrome";
            extensions = chromiumStandardExtensions;
            flags = {
              verticalTabs = false;
              vaapi = true;
              wayland = true;
            };
          };
          helium = {
            enable = true;
            # Helium AppImage sandbox maps /etc/chromium into the bwrap container
            # so policies must go through the chromium path for the sandbox.
            policyPath = "chromium";
            extensionUpdateUrl = "https://services.helium.imput.net/ext";
            extensions = chromiumStandardExtensions;
            removedExtensions = heliumBundledExtensionsToRemove;
            flags = {
              verticalTabs = true;
              vaapi = true;
              wayland = true;
            };
          };
          vivaldi = {
            enable = true;
            policyPath = "opt/vivaldi";
            extensions = chromiumStandardExtensions;
            flags = {
              verticalTabs = true;
              vaapi = true;
              wayland = true;
            };
          };
        };
      };

      nix.settings.trusted-users = [
        "root"
        "warby"
        "@wheel"
      ];

      boot = {
        plymouth.enable = true;
        consoleLogLevel = 3;
        initrd.verbose = false;
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
        kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
        kernelParams = [
          "usbcore.autosuspend=-1"
          "quiet"
          "udev.log_level=3"
          "systemd.show_status=auto"
        ];
      };

      time.timeZone = "America/Chicago";
      i18n.defaultLocale = "en_US.UTF-8";
      i18n.extraLocaleSettings = {
        LC_ADDRESS = "en_US.UTF-8";
        LC_IDENTIFICATION = "en_US.UTF-8";
        LC_MEASUREMENT = "en_US.UTF-8";
        LC_MONETARY = "en_US.UTF-8";
        LC_NAME = "en_US.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_PAPER = "en_US.UTF-8";
        LC_TELEPHONE = "en_US.UTF-8";
        LC_TIME = "en_US.UTF-8";
      };

      networking.networkmanager = {
        enable = true;
        plugins = with pkgs; [ networkmanager-openvpn ];
      };

      services.tailscale = {
        enable = true;
        # Resolve private tailnet hostnames through MagicDNS.
        extraSetFlags = [ "--accept-dns=true" ];
      };

      services.fehWaydroid = {
        enable = true;
        user = "warby";
        width = 720;
        height = 1280;
        useNftables = true;
      };

      services.adguardhome = {
        enable = true;
        openFirewall = true;
        port = 8080;
        settings = {
          dns = {
            bind_host = "0.0.0.0";
            port = 53;
            upstream_dns = [
              "https://dns.quad9.net/dns-query"
              "tls://dns.quad9.net"
            ];
            bootstrap_dns = [
              "9.9.9.9"
              "149.112.112.112"
            ];
            ratelimit = 30;
            cache_size = 8388608;
          };
          filtering = {
            enabled = true;
          };
        };
      };

      services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
        settings.KbdInteractiveAuthentication = false;
      };

      networking.firewall = {
        allowedTCPPorts = [
          3000 # Plex MPV Shim control
        ];
        allowedUDPPorts = [
          32410 # Plex GDM discovery
          32412
          32413
          32414
        ];
        allowedUDPPortRanges = [
          {
            from = 60000;
            to = 61000;
          } # Mosh
        ];
      };

      system.stateVersion = "25.05";
    };
}
