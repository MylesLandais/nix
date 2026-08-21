# Local LLM inference behind a llama-swap model router.
#
# The card is a single RTX 3090 Ti (24 GB, Ampere/sm86), so exactly one 30B-class
# model fits at a time. Giving each model its own port would mean every downstream
# client has to know which model is currently resident and follow it around — so
# instead llama-swap owns a single stable port and routes on the `model` field of
# the OpenAI request, stopping the previous backend before starting the next:
#
#   client -> llama-swap :8000 -> docker run <backend> on an ephemeral ${PORT}
#
# Two backends, because no single engine covers the models under test:
#
#   vllm      the fast path for safetensors checkpoints with a real vLLM
#             quantization (NVFP4/W4A16, GPTQ, AWQ, compressed-tensors).
#   llamacpp  for GGUF-only releases. vLLM's GGUF support is experimental and
#             does not cover mmproj (multimodal) or draft models at all, which
#             some of these checkpoints ship as their only 24 GB-viable form.
#
# llama-swap is backend-agnostic — anything speaking the OpenAI API works — so
# mixing the two costs nothing downstream. Clients still see one port and one
# model list.
#
# Consequences worth knowing before touching this:
#
#   * The first request after a switch blocks for the model load (tens of seconds
#     for a 30B). That is the cost of one card; there is no way around it.
#   * /v1/models lists every declared model regardless of what is loaded, so
#     client-side model pickers work normally.
#   * Backends deliberately do NOT run as virtualisation.oci-containers.
#     llama-swap has to own the process lifecycle in order to swap it; a static
#     oci-container unit would fight it for the same GPU. Upstream specifically
#     recommends containerising Python inference servers so they respond properly
#     to SIGTERM, paired with cmdStop.
#   * Containers also pin engine versions per model. nixpkgs is on vLLM 0.24.0,
#     but NVIDIA's Ampere recipe for Nemotron requires 0.27.1, and a CUDA source
#     build of vLLM is hours of uncached compiling (see sunshine.nix for the same
#     reasoning applied to a frozen nixpkgs).
_: {
  flake.nixosModules.llmRouter =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.infra.llmRouter;

      # llama-swap substitutes ${PORT} itself when it launches a backend, picking
      # a free port per model. It must survive Nix interpolation untouched.
      upstreamPort = "\${PORT}";

      # Shared `docker run` preamble. --ipc=host matters for vLLM specifically:
      # its worker processes talk over shared memory and the default 64 MB
      # /dev/shm shows up as a silent hang during model load, not an error.
      dockerRun =
        name: image: extraDocker:
        [
          "${pkgs.docker}/bin/docker run --rm"
          "--name llm-${name}"
          "--device=nvidia.com/gpu=all"
          "--ipc=host"
          "-p ${upstreamPort}:${upstreamPort}"
        ]
        ++ extraDocker
        # The image name terminates docker's own options: everything after it is
        # argv for the container. Per-backend mounts must therefore come first.
        ++ [ image ];

      backendArgs = {
        vllm = name: m: {
          docker = [ "-v ${cfg.hfCacheDir}:/root/.cache/huggingface" ];
          args = [
            "--model ${m.model}"
            "--port ${upstreamPort}"
            "--host 0.0.0.0"
            # Name the endpoint after the attribute key rather than the HF repo
            # id, so clients ask for "nemotron", not the full slug.
            "--served-model-name ${name}"
          ];
        };
        llamacpp = name: m: {
          docker = [
            "-v ${cfg.llamaCacheDir}:/root/.cache/llama.cpp"
            "-e LLAMA_CACHE=/root/.cache/llama.cpp"
          ];
          # llama-server pulls straight from HuggingFace, so GGUF models need no
          # separate download step and the mount above keeps them across swaps.
          #
          # Use the two-flag form, NOT the shorthand `-hf repo:file`: the
          # shorthand expects a quant *label* and rejects a full filename with
          # "exactly one out metadata, path_model, and file must be defined",
          # which these repos need because they ship several quants each.
          args = [
            "--hf-repo ${m.model}"
            "--hf-file ${m.file}"
            "--port ${upstreamPort}"
            "--host 0.0.0.0"
            "--alias ${name}"
          ];
        };
      };

      mkCmd =
        name: m:
        let
          image = if m.image != null then m.image else cfg.images.${m.backend};
          b = backendArgs.${m.backend} name m;
        in
        lib.concatStringsSep " " (dockerRun name image b.docker ++ b.args ++ m.extraArgs);

      settings = {
        # A 30B has to be pulled off disk and packed onto the card before it
        # answers; the 120 s default expires mid-load and llama-swap gives up.
        # First run is slower still, since the weights are downloaded too.
        healthCheckTimeout = 1800;
        logLevel = "info";
        models = lib.mapAttrs (name: m: {
          cmd = mkCmd name m;
          # Stop the container by name rather than signalling the `docker run`
          # client. Killing the client detaches without tearing down the
          # container, which would leave the model resident and the next swap
          # would OOM on a card that looks free to llama-swap.
          cmdStop = "${pkgs.docker}/bin/docker stop --time 30 llm-${name}";
          inherit (cfg) ttl;
        }) cfg.models;
      };

      configFile = (pkgs.formats.yaml { }).generate "llama-swap.yaml" settings;
    in
    {
      options.services.infra.llmRouter = {
        enable = lib.mkEnableOption "llama-swap LLM router with vLLM/llama.cpp backends";

        port = lib.mkOption {
          type = lib.types.port;
          default = 8000;
          description = ''
            The stable, client-facing OpenAI-compatible endpoint. This is the only
            port anything downstream should ever learn; backends get ephemeral
            ports assigned by llama-swap.
          '';
        };

        images = {
          vllm = lib.mkOption {
            type = lib.types.str;
            default = "vllm/vllm-openai:v0.27.1";
            description = ''
              Default vLLM image. Pinned, never ":latest" — the serve flags in each
              model's extraArgs are version-specific, and a silently updated image
              turns a working model into a startup failure.
            '';
          };
          llamacpp = lib.mkOption {
            type = lib.types.str;
            default = "ghcr.io/ggml-org/llama.cpp:server-cuda";
            description = "Default llama.cpp server image (CUDA build).";
          };
        };

        hfCacheDir = lib.mkOption {
          type = lib.types.path;
          default = "/home/${cfg.user}/.cache/llm/huggingface";
          defaultText = lib.literalExpression ''"/home/''${cfg.user}/.cache/llm/huggingface"'';
          description = ''
            Host-side HuggingFace cache for vLLM backends, bind-mounted into each
            so the ~20 GB of weights per model are downloaded once and survive
            swaps.
          '';
        };

        llamaCacheDir = lib.mkOption {
          type = lib.types.path;
          default = "/home/${cfg.user}/.cache/llm/llama.cpp";
          defaultText = lib.literalExpression ''"/home/''${cfg.user}/.cache/llm/llama.cpp"'';
          description = "Host-side GGUF cache for llama.cpp backends.";
        };

        ttl = lib.mkOption {
          type = lib.types.int;
          default = 1800;
          description = ''
            Seconds of idleness before a backend is unloaded and its VRAM handed
            back. Without this the last model tested keeps the whole card until
            something else asks for it — which matters because this is a desktop
            and the compositor wants VRAM too.
          '';
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "warby";
          description = ''
            User to run llama-swap as. Cannot be DynamicUser: it drives the Docker
            socket, so it must be a real account in the "docker" group.
          '';
        };

        models = lib.mkOption {
          default = { };
          description = "Models to expose. The attribute name is the id clients request.";
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                backend = lib.mkOption {
                  type = lib.types.enum [
                    "vllm"
                    "llamacpp"
                  ];
                  default = "vllm";
                  description = "Inference engine. Use llamacpp for GGUF-only releases.";
                };
                model = lib.mkOption {
                  type = lib.types.str;
                  description = "HuggingFace repo id (vLLM's --model / llama-server's --hf-repo).";
                };
                file = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    llamacpp only: the exact .gguf filename within the repo. These
                    repos ship many quants and there is no sane default — picking
                    the wrong one silently loads a model that does not fit.
                  '';
                };
                image = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Override the default image for this model only.";
                };
                extraArgs = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = ''
                    Extra engine flags. Always bound the context here: these
                    checkpoints advertise 131K-1M context that a 24 GB KV cache
                    cannot fund, and vLLM refuses to start rather than trim it
                    (--max-model-len for vLLM, -c for llama-server).
                  '';
                };
              };
            }
          );
        };
      };

      config = lib.mkIf cfg.enable {
        # Catch this at build time: llama-server would otherwise start, download
        # nothing, and fail deep in model loading with an opaque message.
        assertions = lib.mapAttrsToList (name: m: {
          assertion = m.backend != "llamacpp" || m.file != null;
          message = "services.infra.llmRouter.models.${name}: the llamacpp backend requires `file` (the .gguf filename).";
        }) cfg.models;

        virtualisation.docker.enable = true;
        hardware.nvidia-container-toolkit.enable = true;

        # FIX: Workaround for nvidia-container-toolkit issue
        # https://github.com/NixOS/nixpkgs/issues/463525
        # Without this the CDI spec is never generated and every backend starts
        # without a GPU, failing deep inside torch rather than at `docker run`.
        systemd.services.nvidia-container-toolkit-cdi-generator.serviceConfig.ExecStartPre =
          lib.mkForce null;

        users.users.${cfg.user}.extraGroups = [ "docker" ];

        # These caches hold ~17-19 GB per model. They live under the router
        # user's home rather than /var/cache so that pre-seeding, pruning and
        # re-downloading a bad quant need no root — which matters because a
        # wrong `file =` here costs a 17 GB re-fetch, and that is a thing you
        # want to fix without sudo. The router already runs as this user.
        systemd.tmpfiles.rules = [
          "d ${cfg.hfCacheDir} 0755 ${cfg.user} users - -"
          "d ${cfg.llamaCacheDir} 0755 ${cfg.user} users - -"
        ];

        systemd.services.llama-swap = {
          description = "llama-swap LLM model router";
          after = [
            "network-online.target"
            "docker.service"
          ];
          wants = [ "network-online.target" ];
          requires = [ "docker.service" ];
          wantedBy = [ "multi-user.target" ];

          # Repo-wide convention: bound restart loops rather than letting a
          # failing unit spin (see valkey.nix / pyload.nix).
          startLimitIntervalSec = 300;
          startLimitBurst = 5;

          path = [ pkgs.docker ];

          serviceConfig = {
            # Loopback only, and deliberately absent from networking.firewall:
            # this is an unauthenticated endpoint that will run arbitrary
            # generation for anyone who can reach it. Putting it on the tailnet
            # should be a deliberate, separate change.
            ExecStart = "${pkgs.llama-swap}/bin/llama-swap --config ${configFile} --listen 127.0.0.1:${toString cfg.port}";

            User = cfg.user;
            Restart = "on-failure";
            RestartSec = "5s";

            NoNewPrivileges = true;
            PrivateTmp = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              # The Docker socket is a unix socket; dropping AF_UNIX would break
              # every backend launch.
              "AF_UNIX"
            ];
          };
        };
      };
    };
}
