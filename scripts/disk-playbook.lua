#!/usr/bin/env lua
-- Disk Playbook: Filesystem monitoring, automated maintenance, and nightly reporting.
-- Designed for NixOS hosts (Cerberus) to protect root storage without risking
-- production data, git trees, or untracked source files.

local os = os
local io = io
local string = string
local math = math
local table = table

-- ---------------------------------------------------------------------------
-- Configuration & Policy
-- ---------------------------------------------------------------------------
local HOME = os.getenv("HOME") or "/home/warby"

local CONFIG = {
  -- Root NVMe plus the second NVMe (btrfs fast-workspace). Thresholds act on
  -- whichever is fullest.
  mounts = { "/", HOME .. "/Workspace" },
  thresholds = {
    warning  = 75, -- Start warning in reports/status
    action   = 80, -- Auto-reclaim triggered in nightly runs
    critical = 90, -- Urgent alerts & aggressive safe reclaim
  },
  reports_dir = HOME .. "/.local/state/disk-reports",
  retention_days = 30,
  stale_build_days = 7,  -- Targets unmodified for 7+ days are pruned at action threshold
  active_build_days = 1, -- Even at critical, a build tree touched within a day is kept
  roots = {
    HOME .. "/Workspace*",
    HOME .. "/workspace*",
    HOME .. "/.cache",
  },
  cache_dirs = {
    HOME .. "/.cache/uv",
    HOME .. "/.cache/pip",
    HOME .. "/.npm/_cacache",
    HOME .. "/.cache/yarn",
    HOME .. "/.cache/go-build",
    HOME .. "/.cargo/registry/cache",
  },
  -- Codex copies its ~47 MB bundled marketplace out of the read-only Nix store
  -- here, keeps the 0555/0444 modes, and then can't delete the copy: up to
  -- ~50/hour while in use, 133 GiB by 2026-11-06.
  codex_staging_dir = HOME .. "/.codex/.tmp/bundled-marketplaces",
  codex_staging_days = 1,
  top_consumers = 15,
}

-- ---------------------------------------------------------------------------
-- Utilities
-- ---------------------------------------------------------------------------
local function exec_read(cmd)
  local handle = io.popen(cmd)
  if not handle then return "" end
  local result = handle:read("*a")
  handle:close()
  return result or ""
end

local function trim(s)
  return s:match("^%s*(.-)%s*$") or ""
end

local function human_size(bytes)
  bytes = tonumber(bytes) or 0
  local units = { "B", "KiB", "MiB", "GiB", "TiB" }
  local idx = 1
  while bytes >= 1024 and idx < #units do
    bytes = bytes / 1024
    idx = idx + 1
  end
  if idx == 1 then
    return string.format("%d %s", bytes, units[idx])
  else
    return string.format("%.1f %s", bytes, units[idx])
  end
end

local function dir_size_bytes(path)
  local out = exec_read(string.format("du -xsb %q 2>/dev/null | awk '{print $1}'", path))
  return tonumber(trim(out)) or 0
end

-- A tree's own mtime only moves when its top level gains entries. The
-- per-crate fingerprint and incremental dirs three levels down move on every
-- build, so take the newest mtime down to that depth.
local function newest_mtime_epoch(path)
  local out = exec_read(string.format(
    "find %q -maxdepth 3 -printf '%%T@\\n' 2>/dev/null | sort -n | tail -n 1", path))
  return math.floor(tonumber(trim(out)) or 0)
end

local function notify(summary, body, urgency)
  urgency = urgency or "normal"
  local cmd = string.format(
    "notify-send -u %q -a %q %q %q 2>/dev/null || true",
    urgency, "Disk Playbook", summary, body
  )
  os.execute(cmd)
end

-- ---------------------------------------------------------------------------
-- Core Auditing & Inspection
-- ---------------------------------------------------------------------------
local function get_disk_capacity(mount)
  mount = mount or CONFIG.mounts[1]
  local raw = exec_read(string.format("df -P -k %q 2>/dev/null | awk 'NR==2{print $2, $3, $4, $5}'", mount))
  local total_k, used_k, avail_k, pct_str = raw:match("(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%%")
  total_k = tonumber(total_k) or 0
  used_k = tonumber(used_k) or 0
  avail_k = tonumber(avail_k) or 0
  local pct = tonumber(pct_str) or 0

  return {
    mount = mount,
    total_bytes = total_k * 1024,
    used_bytes = used_k * 1024,
    avail_bytes = avail_k * 1024,
    percent_used = pct,
  }
end

local function get_all_capacities()
  local caps = {}
  for _, m in ipairs(CONFIG.mounts) do
    table.insert(caps, get_disk_capacity(m))
  end
  return caps
end

-- The fullest mount drives the alert level and the reclaim decision.
local function get_worst_capacity()
  local worst
  for _, cap in ipairs(get_all_capacities()) do
    if not worst or cap.percent_used > worst.percent_used then worst = cap end
  end
  return worst
end

local function alert_level(pct)
  if pct >= CONFIG.thresholds.critical then return "critical" end
  if pct >= CONFIG.thresholds.action then return "action" end
  if pct >= CONFIG.thresholds.warning then return "warning" end
  return "normal"
end

-- Only directories cargo itself tagged count. That covers in-tree target/ and
-- out-of-tree CARGO_TARGET_DIRs (fusion-playthrough-target, ~/.cache/nebula-*),
-- and skips non-cargo output that merely sits in a dir named target/.
local function is_cargo_target(path)
  local f = io.open(path .. "/CACHEDIR.TAG", "r")
  if not f then return false end
  local tag = f:read("*a") or ""
  f:close()
  return tag:find("created by cargo", 1, true) ~= nil
end

local function find_cargo_target_dirs(min_age_days)
  local targets = {}
  local seen = {}
  local now = os.time()
  local min_age_sec = (min_age_days or 0) * 86400

  local candidates = {}
  for _, pattern in ipairs(CONFIG.roots) do
    local cmd = string.format("find %s -maxdepth 4 -type f -name CACHEDIR.TAG -printf '%%h\\n' 2>/dev/null", pattern)
    local out = exec_read(cmd)
    for line in out:gmatch("[^\r\n]+") do
      local path = trim(line)
      if #path > 0 and is_cargo_target(path) then
        table.insert(candidates, path)
      end
    end
  end

  -- Cross-compile targets (<target>/wasm32-unknown-unknown) carry their own
  -- tag; keep only the outermost tree so sizes aren't counted twice.
  table.sort(candidates, function(a, b) return #a < #b end)
  for _, path in ipairs(candidates) do
    local nested = seen[path]
    for parent in pairs(seen) do
      if path:sub(1, #parent + 1) == parent .. "/" then nested = true end
    end
    if not nested then
      seen[path] = true
      local mtime = newest_mtime_epoch(path)
      local age_days = (now - mtime) / 86400
      if min_age_days == 0 or (now - mtime) >= min_age_sec then
        local size = dir_size_bytes(path)
        table.insert(targets, {
          path = path,
          size_bytes = size,
          age_days = math.floor(age_days * 10) / 10,
          mtime = mtime
        })
      end
    end
  end

  table.sort(targets, function(a, b) return a.size_bytes > b.size_bytes end)
  return targets
end

local function get_cache_candidates()
  local items = {}
  for _, path in ipairs(CONFIG.cache_dirs) do
    local size = dir_size_bytes(path)
    if size > 0 then
      table.insert(items, { path = path, size_bytes = size })
    end
  end
  return items
end

local function codex_staging_find(action)
  return string.format(
    "find %q -mindepth 1 -maxdepth 1 -name 'openai-bundled.staging-*' -mmin +%d %s 2>/dev/null",
    CONFIG.codex_staging_dir, CONFIG.codex_staging_days * 1440, action
  )
end

local function get_codex_staging()
  local out = exec_read(codex_staging_find("-exec du -sb {} +") .. " | awk '{n++; s+=$1} END{print n+0, s+0}'")
  local n, s = out:match("(%d+)%s+(%d+)")
  return { count = tonumber(n) or 0, size_bytes = tonumber(s) or 0 }
end

local function get_top_consumers(path, limit)
  local out = exec_read(string.format(
    "du -xb --max-depth=1 %q 2>/dev/null | sort -rn | head -n %d", path, limit + 1))
  local items = {}
  for size, p in out:gmatch("(%d+)\t([^\n]+)") do
    if p ~= path then
      table.insert(items, { path = p, size_bytes = tonumber(size) })
    end
  end
  return items
end

local function get_docker_summary()
  -- `docker system df` walks every volume; with ~280 of them it needs tens of seconds.
  local out = exec_read("timeout 90s docker system df 2>/dev/null")
  if #out == 0 then return nil end

  local images_reclaim = out:match("Images%s+%d+%s+%d+%s+[%d%.]+%a*B%s+([%d%.]+%a*B)") or "0B"
  local containers_reclaim = out:match("Containers%s+%d+%s+%d+%s+[%d%.]+%a*B%s+([%d%.]+%a*B)") or "0B"
  local volumes_reclaim = out:match("Local Volumes%s+%d+%s+%d+%s+[%d%.]+%a*B%s+([%d%.]+%a*B)") or "0B"
  local build_reclaim = out:match("Build Cache%s+%d+%s+%d+%s+[%d%.]+%a*B%s+([%d%.]+%a*B)") or "0B"

  return {
    raw = out,
    images_reclaim = images_reclaim,
    containers_reclaim = containers_reclaim,
    volumes_reclaim = volumes_reclaim,
    build_reclaim = build_reclaim,
  }
end

-- ---------------------------------------------------------------------------
-- Reclaim Action Engine (Safe Execution Only)
-- ---------------------------------------------------------------------------
local function execute_reclaim(opts)
  opts = opts or {}
  local apply = opts.apply or false
  local min_age_days = opts.min_age_days or 0
  local tiers = opts.tiers or { build = true, cache = true, codex = true, docker = true, nix = true, logs = true }

  local results = {
    freed_bytes = 0,
    actions = {}
  }

  local function record(name, size, detail)
    results.freed_bytes = results.freed_bytes + size
    table.insert(results.actions, {
      name = name,
      size_bytes = size,
      detail = detail,
      applied = apply
    })
  end

  -- Tier: Build Artifacts (cargo-tagged target dirs)
  -- TODO(disk): also prune debug/incremental/<crate>-<hash> dirs untouched for
  -- stale_build_days inside trees that are still active. Incremental stays on
  -- (it saves long rebuilds); dead test/bin/feature variants were 24 of 40 GiB
  -- in nebula-channel-reactions-build on 2026-11-06. Worst case is one
  -- non-incremental compile of that crate.
  if tiers.build then
    local targets = find_cargo_target_dirs(min_age_days)
    for _, t in ipairs(targets) do
      if t.size_bytes > 1024 * 1024 then -- Skip trivial empty target dirs
        if apply then
          os.execute(string.format("rm -rf -- %q", t.path))
        end
        record("Rust Target", t.size_bytes, string.format("%s (age: %.1f days)", t.path, t.age_days))
      end
    end
  end

  -- Tier: Package Caches (uv, pip, npm)
  if tiers.cache then
    local caches = get_cache_candidates()
    for _, c in ipairs(caches) do
      if apply then
        os.execute(string.format("rm -rf -- %q", c.path))
      end
      record("Package Cache", c.size_bytes, c.path)
    end
  end

  -- Tier: Codex marketplace staging copies (leaked temp dirs, never reused)
  if tiers.codex then
    local c = get_codex_staging()
    if c.count > 0 then
      if apply then
        -- The copies keep the Nix store's read-only modes, which is also why
        -- Codex can't clean them up itself; plain rm -rf fails the same way.
        os.execute(codex_staging_find([[-exec sh -c 'chmod -R u+w "$@" && rm -rf -- "$@"' sh {} +]]))
      end
      record("Codex Staging", c.size_bytes, string.format(
        "%d leaked marketplace copies older than %dd in %s", c.count, CONFIG.codex_staging_days, CONFIG.codex_staging_dir))
    end
  end

  -- Tier: Docker Prune (Images & Build Cache ONLY - NEVER volumes)
  if tiers.docker then
    if apply then
      -- Dangling only: -a would also delete the vLLM/SGLang images llm-router
      -- runs with --rm, forcing a 10-20 GB re-pull on the next model swap.
      os.execute("docker image prune -f >/dev/null 2>&1 || true")
      os.execute("docker builder prune -f --filter until=168h >/dev/null 2>&1 || true")
    end
    record("Docker", 0, "Pruned dangling images and build cache older than 7d (volumes strictly kept)")
  end

  -- Tier: Nix GC & Profile Wipe
  if tiers.nix then
    if apply then
      os.execute("nix profile wipe-history --older-than 7d >/dev/null 2>&1 || true")
      os.execute("nix-collect-garbage --delete-older-than 7d >/dev/null 2>&1 || true")
    end
    record("Nix Store", 0, "Wiped per-user profile history (>7d) and ran nix-collect-garbage (>7d)")
  end

  -- Tier: Logs Vacuum
  if tiers.logs then
    if apply then
      os.execute("journalctl --user --vacuum-size=200M >/dev/null 2>&1 || true")
    end
    record("Journald", 0, "Vacuumed user journal logs to 200M")
  end

  return results
end

local function reclaim_min_age(cap)
  if cap.percent_used >= CONFIG.thresholds.critical then
    return CONFIG.active_build_days
  end
  return CONFIG.stale_build_days
end

-- ---------------------------------------------------------------------------
-- Subcommands
-- ---------------------------------------------------------------------------

local function cmd_status()
  local labels = {
    critical = "CRITICAL (Action Required)",
    action = "ACTION (Auto-cleanup active)",
    warning = "WARNING (Approaching threshold)",
    normal = "NORMAL",
  }
  print("=================================================================")
  print(" Disk Playbook - Filesystem Status")
  print("=================================================================")
  for _, cap in ipairs(get_all_capacities()) do
    print(string.format("Mount:       %s", cap.mount))
    print(string.format("Capacity:    %s Total | %s Used (%d%%) | %s Available",
      human_size(cap.total_bytes),
      human_size(cap.used_bytes),
      cap.percent_used,
      human_size(cap.avail_bytes)
    ))
    print(string.format("Alert State: %s", labels[alert_level(cap.percent_used)]))
    print("-----------------------------------------------------------------")
  end

  -- Quick target scan
  local targets = find_cargo_target_dirs(0)
  local target_bytes = 0
  for _, t in ipairs(targets) do target_bytes = target_bytes + t.size_bytes end
  print(string.format("Rust target/ dirs:      %d found (%s total)", #targets, human_size(target_bytes)))

  -- Cache scan
  local caches = get_cache_candidates()
  local cache_bytes = 0
  for _, c in ipairs(caches) do cache_bytes = cache_bytes + c.size_bytes end
  print(string.format("Package caches (uv/npm): %d found (%s total)", #caches, human_size(cache_bytes)))

  local codex = get_codex_staging()
  print(string.format("Codex staging leak:     %d copies (%s)", codex.count, human_size(codex.size_bytes)))

  -- Docker
  local docker = get_docker_summary()
  if docker then
    print(string.format("Docker reclaimable:     Images %s | Volumes %s | Build Cache %s",
      docker.images_reclaim, docker.volumes_reclaim, docker.build_reclaim))
  end
  print("=================================================================")
end

local function generate_markdown_report()
  local caps = get_all_capacities()
  local now_str = os.date("%Y-%m-%d %H:%M:%S")
  local targets = find_cargo_target_dirs(0)
  local caches = get_cache_candidates()
  local codex = get_codex_staging()
  local docker = get_docker_summary()
  local status_tags = {
    critical = "🔴 Critical",
    action = "🟡 Action Threshold Triggered",
    warning = "🟠 Warning",
    normal = "🟢 Normal",
  }

  local lines = {}
  table.insert(lines, "# Nightly Disk & System Maintenance Report")
  table.insert(lines, string.format("**Generated**: %s | **Host**: %s", now_str, trim(exec_read("hostname"))))
  table.insert(lines, "")
  table.insert(lines, "## 1. Capacity & Threshold Status")
  table.insert(lines, "| Mount | Total | Used | Available | Status |")
  table.insert(lines, "| :--- | :--- | :--- | :--- | :--- |")
  for _, cap in ipairs(caps) do
    table.insert(lines, string.format("| `%s` | %s | %s (**%d%%**) | %s | %s |",
      cap.mount, human_size(cap.total_bytes), human_size(cap.used_bytes), cap.percent_used,
      human_size(cap.avail_bytes), status_tags[alert_level(cap.percent_used)]))
  end
  table.insert(lines, "")

  table.insert(lines, "## 2. Reclaimable Build Targets (cargo-tagged)")
  if #targets == 0 then
    table.insert(lines, "_No Cargo target directories found._")
  else
    table.insert(lines, "| Path | Size | Age (Days) |")
    table.insert(lines, "| :--- | :--- | :--- |")
    for _, t in ipairs(targets) do
      if t.size_bytes > 50 * 1024 * 1024 then -- Show >= 50 MB
        table.insert(lines, string.format("| `%s` | %s | %.1f |", t.path, human_size(t.size_bytes), t.age_days))
      end
    end
  end
  table.insert(lines, "")

  table.insert(lines, "## 3. Package & Tool Caches")
  if #caches == 0 then
    table.insert(lines, "_No significant package caches found._")
  else
    table.insert(lines, "| Cache Path | Size |")
    table.insert(lines, "| :--- | :--- |")
    for _, c in ipairs(caches) do
      table.insert(lines, string.format("| `%s` | %s |", c.path, human_size(c.size_bytes)))
    end
  end
  table.insert(lines, string.format("- **Codex staging leak**: %d copies older than %dd (%s) in `%s`",
    codex.count, CONFIG.codex_staging_days, human_size(codex.size_bytes), CONFIG.codex_staging_dir))
  table.insert(lines, "")

  table.insert(lines, "## 4. Docker Storage")
  if docker then
    table.insert(lines, string.format("- **Reclaimable Images**: %s", docker.images_reclaim))
    table.insert(lines, string.format("- **Unused Volumes**: %s (review by hand; never auto-pruned)", docker.volumes_reclaim))
    table.insert(lines, string.format("- **Build Cache**: %s", docker.build_reclaim))
    table.insert(lines, "_Note: Docker volumes are strictly preserved to safeguard persistent application state._")
  else
    table.insert(lines, "_`docker system df` did not answer within 90s._")
  end
  table.insert(lines, "")

  -- Cold data is the bulk of every fill-up and no tier can safely delete it,
  -- so surface the biggest directories for a human to decide on.
  table.insert(lines, "## 5. Largest Directories")
  for _, path in ipairs({ HOME, HOME .. "/Workspace" }) do
    table.insert(lines, string.format("### `%s`", path))
    table.insert(lines, "| Path | Size |")
    table.insert(lines, "| :--- | :--- |")
    for _, item in ipairs(get_top_consumers(path, CONFIG.top_consumers)) do
      table.insert(lines, string.format("| `%s` | %s |", item.path, human_size(item.size_bytes)))
    end
    table.insert(lines, "")
  end

  table.insert(lines, "## 6. Storage Invariants & Policy")
  table.insert(lines, "- [x] Git repositories, untracked code, and dirty worktrees protected.")
  table.insert(lines, "- [x] Persistent database and Docker volumes excluded from automatic deletion.")
  table.insert(lines, string.format("- [x] Automatic cleanup activates when any mount reaches **%d%%**.", CONFIG.thresholds.action))
  table.insert(lines, string.format("- [x] Build trees touched within **%d day(s)** are kept even at critical.", CONFIG.active_build_days))

  return table.concat(lines, "\n")
end

local function cmd_report(out_file)
  local report = generate_markdown_report()
  if out_file and #out_file > 0 then
    os.execute(string.format("mkdir -p %q", (out_file:gsub("/[^/]+$", ""))))
    local f = io.open(out_file, "w")
    if f then
      f:write(report)
      f:close()
      print(string.format("Report written to %s", out_file))
    else
      print(string.format("Failed to write to %s", out_file))
    end
  else
    print(report)
  end
end

local function cmd_check()
  local cap = get_worst_capacity()
  print(string.format("Dry run evaluation (fullest mount %s, %d%% used):", cap.mount, cap.percent_used))
  local results = execute_reclaim({ apply = false, min_age_days = reclaim_min_age(cap) })
  print(string.format("Total candidate space to reclaim: %s", human_size(results.freed_bytes)))
  for _, a in ipairs(results.actions) do
    if a.size_bytes > 0 then
      print(string.format("  - [%s] %s (%s)", a.name, a.detail, human_size(a.size_bytes)))
    else
      print(string.format("  - [%s] %s", a.name, a.detail))
    end
  end
end

local function cmd_clean(force)
  local cap = get_worst_capacity()
  if not force and cap.percent_used < CONFIG.thresholds.action then
    print(string.format(
      "Fullest mount %s is at %d%% (below action threshold of %d%%). No cleanup required.",
      cap.mount, cap.percent_used, CONFIG.thresholds.action
    ))
    print("Pass --force to run cleanup regardless of threshold.")
    return
  end

  print(string.format("Executing cleanup (fullest mount %s at %d%% used)...", cap.mount, cap.percent_used))
  local results = execute_reclaim({ apply = true, min_age_days = reclaim_min_age(cap) })
  print(string.format("Successfully freed %s.", human_size(results.freed_bytes)))

  for _, after in ipairs(get_all_capacities()) do
    print(string.format("New disk status %s: %d%% used (%s available).",
      after.mount, after.percent_used, human_size(after.avail_bytes)))
  end
end

local function cmd_nightly()
  os.execute(string.format("mkdir -p %q", CONFIG.reports_dir))

  -- 1. Rotate old reports (> 30 days)
  os.execute(string.format(
    "find %q -name 'report-*.md' -mtime +%d -delete 2>/dev/null || true",
    CONFIG.reports_dir, CONFIG.retention_days
  ))

  -- 2. Generate and write nightly report
  local today = os.date("%Y-%m-%d")
  local report_path = string.format("%s/report-%s.md", CONFIG.reports_dir, today)
  local latest_symlink = string.format("%s/latest.md", CONFIG.reports_dir)

  local report = generate_markdown_report()
  local f = io.open(report_path, "w")
  if f then
    f:write(report)
    f:close()
    os.execute(string.format("ln -sf %q %q", report_path, latest_symlink))
  end

  -- 3. Evaluate threshold and action
  local cap = get_worst_capacity()
  local level = alert_level(cap.percent_used)
  if level == "critical" or level == "action" then
    local res = execute_reclaim({ apply = true, min_age_days = reclaim_min_age(cap) })
    local after = get_disk_capacity(cap.mount)
    notify(
      level == "critical" and "CRITICAL: Disk Usage Alert" or "Automated Disk Maintenance",
      string.format("%s was at %d%%. Reclaimed %s. Current: %d%% (%s free).",
        cap.mount, cap.percent_used, human_size(res.freed_bytes), after.percent_used, human_size(after.avail_bytes)),
      level == "critical" and "critical" or "normal"
    )
  elseif level == "warning" then
    notify(
      "Disk Space Warning",
      string.format("%s usage at %d%% (%s free). Approaching %d%% action threshold.",
        cap.mount, cap.percent_used, human_size(cap.avail_bytes), CONFIG.thresholds.action),
      "normal"
    )
  end
end

-- ---------------------------------------------------------------------------
-- Entry Point
-- ---------------------------------------------------------------------------
local arg1 = arg[1] or "status"

if arg1 == "status" then
  cmd_status()
elseif arg1 == "report" then
  cmd_report(arg[2])
elseif arg1 == "check" then
  cmd_check()
elseif arg1 == "clean" or arg1 == "apply" then
  local force = (arg[2] == "--force" or arg[3] == "--force")
  cmd_clean(force)
elseif arg1 == "nightly" then
  cmd_nightly()
else
  print("Usage: disk-playbook <command> [options]")
  print("Commands:")
  print("  status          Show capacity, alert level, and reclaimable summary")
  print("  report [file]   Generate Markdown analysis report (default stdout)")
  print("  check           Dry-run check of what would be reclaimed")
  print("  clean [--force] Execute safe cleanup (auto-threshold guarded, or --force)")
  print("  nightly         Automated maintenance routine run by systemd timer")
  os.exit(1)
end
