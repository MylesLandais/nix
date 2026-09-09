_: {
  flake.nixosModules.gitMirrors =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.infra.gitMirrors;
      mirrorType = lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Repository name on the Forgejo side.";
          };
          github = lib.mkOption {
            type = lib.types.str;
            example = "MylesLandais/tint";
            description = "Source repo on GitHub as owner/name.";
          };
          forgejoOwner = lib.mkOption {
            type = lib.types.str;
            default = cfg.defaultOwner;
            description = "Owner/org on the Forgejo side.";
          };
          interval = lib.mkOption {
            type = lib.types.str;
            default = cfg.defaultInterval;
            example = "8h0m0s";
            description = "Pull-mirror sync interval (Go duration string).";
          };
          private = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Create the Forgejo repo as private.";
          };
        };
      };
      mappingFile = pkgs.writeText "git-mirrors.json" (
        builtins.toJSON {
          forgejoUrl = cfg.forgejoUrl;
          mirrors = map (m: {
            name = m.name;
            github = m.github;
            forgejoOwner = m.forgejoOwner;
            interval = m.interval;
            private = m.private;
          }) cfg.mirrors;
        }
      );
      syncScript = pkgs.writeShellScriptBin "forgejo-mirror-sync" ''
        export PATH=${
          lib.makeBinPath (
            with pkgs;
            [
              bash
              coreutils
              curl
              jq
              bitwarden-cli
            ]
          )
        }
        set -euo pipefail

        FJ_ITEM="''${FORGEJO_BW_ITEM:-${cfg.forgejoTokenItem}}"
        GH_ITEM="''${GITHUB_BW_ITEM:-${cfg.githubTokenItem}}"
        MAP=${mappingFile}

        if [ -z "''${BW_SESSION:-}" ]; then
          echo 'BW_SESSION is not set. Unlock first (human-in-the-loop):' >&2
          echo '  bw login   # one time per machine' >&2
          echo '  export BW_SESSION=$(bw unlock --raw)' >&2
          exit 1
        fi

        FJ_TOKEN=$(bw get password "$FJ_ITEM" --session "$BW_SESSION")
        if [ -z "$FJ_TOKEN" ]; then
          echo "Forgejo API token item '$FJ_ITEM' came back empty." >&2
          echo "Create a Forgejo token (Settings -> Applications -> Generate New Token," >&2
          echo "scopes: repository read+write, user read) and store it in Bitwarden under '$FJ_ITEM'." >&2
          exit 1
        fi
        GH_TOKEN=$(bw get password "$GH_ITEM" --session "$BW_SESSION" 2>/dev/null || true)

        FORGEJO=$(jq -r .forgejoUrl "$MAP")
        api() { curl -sS -m 30 -H "Authorization: token $FJ_TOKEN" -H 'Content-Type: application/json' "$@"; }

        jq -c '.mirrors[]' "$MAP" | while read -r m; do
          name=$(jq -r .name <<<"$m")
          gh=$(jq -r .github <<<"$m")
          owner=$(jq -r .forgejoOwner <<<"$m")
          interval=$(jq -r .interval <<<"$m")
          private=$(jq -r .private <<<"$m")
          echo "=== $gh -> $owner/$name (every $interval)"

          existing=$(api "$FORGEJO/api/v1/repos/$owner/$name" || true)
          if jq -e '.message == "Not Found" or .message == "Expected Owner or Repo"' <<<"$existing" >/dev/null 2>&1 \
            || [ -z "$existing" ]; then
            echo "  not present on Forgejo; creating as pull mirror"
            payload=$(jq -n \
              --arg addr "https://github.com/$gh.git" \
              --arg ro "$owner" --arg rn "$name" \
              --arg mi "$interval" \
              --argjson priv "$private" \
              --arg svc "github" \
              --arg desc "Pull mirror of https://github.com/$gh" \
              --arg ght "''${GH_TOKEN:-}" \
              '{clone_addr: $addr, repo_owner: $ro, repo_name: $rn,
                mirror: true, mirror_interval: $mi, private: $priv,
                service: $svc, description: $desc}
               + (if $ght == "" then {} else {auth_token: $ght} end)')
            out=$(api -X POST -d "$payload" "$FORGEJO/api/v1/repos/migrate")
            if jq -e .id <<<"$out" >/dev/null 2>&1; then
              echo "  created: $(jq -r .full_name <<<"$out")"
            else
              echo "  CREATE FAILED: $out" >&2
            fi
            continue
          fi

          is_mirror=$(jq -r .mirror <<<"$existing" 2>/dev/null || echo false)
          if [ "$is_mirror" != "true" ]; then
            echo "  EXISTS BUT IS NOT A MIRROR — convert it in the Forgejo web UI" >&2
            echo "  ($owner/$name Settings -> Migrate/Mirror) or delete it and re-run." >&2
            continue
          fi

          if ! api -X PATCH -d "$(jq -n --arg mi "$interval" '{mirror_interval: $mi}')" \
              "$FORGEJO/api/v1/repos/$owner/$name" | jq -e .id >/dev/null 2>&1; then
            echo "  warning: could not set interval via API; check web UI" >&2
          fi
          sync_out=$(api -X POST "$FORGEJO/api/v1/repos/$owner/$name/mirror-sync" || true)
          if [ -z "$sync_out" ] || jq -e 'has("message") | not' <<<"$sync_out" >/dev/null 2>&1; then
            echo "  sync queued"
          else
            echo "  SYNC REQUEST SAID: $sync_out" >&2
          fi
        done
        echo "done."
      '';
    in
    {
      options.services.infra.gitMirrors = {
        enable = lib.mkEnableOption "declarative GitHub -> Forgejo pull-mirror mapping";

        forgejoUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://git.nebula-1.com";
          description = "Base URL of the Forgejo instance.";
        };

        defaultOwner = lib.mkOption {
          type = lib.types.str;
          default = "nebula";
          description = "Default owner/org on the Forgejo side.";
        };

        defaultInterval = lib.mkOption {
          type = lib.types.str;
          default = "8h0m0s";
          description = "Default pull-mirror sync interval (Go duration string).";
        };

        forgejoTokenItem = lib.mkOption {
          type = lib.types.str;
          default = "forgejo-nebula-1-api";
          description = "Bitwarden item holding the Forgejo API token (needs repository scope).";
        };

        githubTokenItem = lib.mkOption {
          type = lib.types.str;
          default = "github-mirror";
          description = "Bitwarden item holding a GitHub PAT (optional; raises rate limits, required for private sources).";
        };

        mirrors = lib.mkOption {
          type = lib.types.listOf mirrorType;
          default = [
            {
              name = "tint";
              github = "MylesLandais/tint";
            }
          ];
          description = "Repos the Forgejo server should pull-mirror from GitHub.";
          example = [
            {
              name = "tint";
              github = "MylesLandais/tint";
              interval = "8h0m0s";
            }
          ];
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ syncScript ];
      };
    };
}
