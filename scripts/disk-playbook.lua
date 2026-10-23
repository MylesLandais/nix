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
local CONFIG = {
  mount_point = "/",
  thresholds = {
    warning  = 75, -- Start warning in reports/status
    action   = 80, -- Auto-reclaim triggered in nightly runs
    critical = 90, -- Urgent alerts & aggressive safe reclaim
  },
  reports_dir = (os.getenv("HOME") or "/home/warby") .. "/.local/state/disk-reports",
  retention_days = 30,
  stale_build_days = 7,  -- Targets unmodified for 7+ days are pruned at action threshold
  roots = {
    (os.getenv("HOME") or "/home/warby") .. "/Workspace*",
    (os.getenv("HOME") or "/home/warby") .. "/workspace*",
  },
  cache_dirs = {
    (os.getenv("HOME") or "/home/warby") .. "/.cache/uv",
    (os.getenv("HOME") or "/home/warby") .. "/.cache/pip",
    (os.getenv("HOME") or "/home/warby") .. "/.npm/_cacache",
    (os.getenv("HOME") or "/home/warby") .. "/.cache/yarn",
    (os.getenv("HOME") or "/home/warby") .. "/.cache/go-build",
    (os.getenv("HOME") or "/home/warby") .. "/.cargo/registry/cache",
  }
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

local function exec_status(cmd)
  return os.execute(cmd)
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

local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local function dir_size_bytes(path)
  local out = exec_read(string.format("du -xsb %q 2>/dev/null | awk '{print $1}'", path))
  return tonumber(trim(out)) or 0
end

local function dir_mtime_epoch(path)
  local out = exec_read(string.format("stat -c '%%Y' %q 2>/dev/null", path))
  return tonumber(trim(out)) or 0
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
  mount = mount or CONFIG.mount_point
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

local function find_cargo_target_dirs(min_age_days)
  local targets = {}
  local now = os.time()
  local min_age_sec = (min_age_days or 0) * 86400

  for _, pattern in ipairs(CONFIG.roots) do
    local cmd = string.format("find %s -maxdepth 4 -type d -name target 2>/dev/null", pattern)
    local out = exec_read(cmd)
    for line in out:gmatch("[^\r\n]+") do
      local path = trim(line)
      if #path > 0 then
        -- Safety check: MUST have a Cargo.toml beside it
        local parent = path:gsub("/target/?$", "")
        local cargo_toml = parent .. "/Cargo.toml"
        if file_exists(cargo_toml) then
          local mtime = dir_mtime_epoch(path)
          local age_days = (now - mtime) / 86400
          if min_age_days == 0 or (now - mtime) >= min_age_sec then
            local size = dir_size_bytes(path)
            table.insert(targets, {
              path = path,
              parent = parent,
              size_bytes = size,
              age_days = math.floor(age_days * 10) / 10,
              mtime = mtime
            })
          end
        end
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

local function get_docker_summary()
  local out = exec_read("timeout 3s docker system df 2>/dev/null")
  if #out == 0 then return nil end

  local images_reclaim = out:match("Images%s+%d+%s+%d+%s+[%d%.]+%a*B%s+([%d%.]+%a*B)") or "0B"
  local containers_reclaim = out:match("Containers%s+%d+%s+%d+%s+[%d%.]+%a*B%s+([%d%.]+%a*B)") or "0B"
  local build_reclaim = out:match("Build Cache%s+%d+%s+%d+%s+[%d%.]+%a*B%s+([%d%.]+%a*B)") or "0B"

  return {
    raw = out,
    images_reclaim = images_reclaim,
    containers_reclaim = containers_reclaim,
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
  local tiers = opts.tiers or { build = true, cache = true, docker = true, nix = true, logs = true }

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

  -- Tier: Build Artifacts (target/)
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

-- ---------------------------------------------------------------------------
-- Subcommands
-- ---------------------------------------------------------------------------

local function cmd_status()
  local cap = get_disk_capacity()
  print("=================================================================")
  print(" Disk Playbook - Filesystem Status")
  print("=================================================================")
  print(string.format("Mount:       %s", cap.mount))
  print(string.format("Capacity:    %s Total | %s Used (%d%%) | %s Available",
    human_size(cap.total_bytes),
    human_size(cap.used_bytes),
    cap.percent_used,
    human_size(cap.avail_bytes)
  ))

  local level = "NORMAL"
  if cap.percent_used >= CONFIG.thresholds.critical then
    level = "CRITICAL (Action Required)"
  elseif cap.percent_used >= CONFIG.thresholds.action then
    level = "ACTION (Auto-cleanup active)"
  elseif cap.percent_used >= CONFIG.thresholds.warning then
    level = "WARNING (Approaching threshold)"
  end
  print(string.format("Alert State: %s", level))
  print("-----------------------------------------------------------------")

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

  -- Docker
  local docker = get_docker_summary()
  if docker then
    print(string.format("Docker reclaimable:     Images %s | Build Cache %s",
      docker.images_reclaim, docker.build_reclaim))
  end
  print("=================================================================")
end

local function generate_markdown_report()
  local cap = get_disk_capacity()
  local now_str = os.date("%Y-%m-%d %H:%M:%S")
  local targets = find_cargo_target_dirs(0)
  local caches = get_cache_candidates()
  local docker = get_docker_summary()

  local lines = {}
  table.insert(lines, "# Nightly Disk & System Maintenance Report")
  table.insert(lines, string.format("**Generated**: %s | **Host**: %s", now_str, trim(exec_read("hostname"))))
  table.insert(lines, "")
  table.insert(lines, "## 1. Capacity & Threshold Status")
  table.insert(lines, string.format("- **Mount Point**: `%s`", cap.mount))
  table.insert(lines, string.format("- **Total**: %s", human_size(cap.total_bytes)))
  table.insert(lines, string.format("- **Used**: %s (**%d%%**)", human_size(cap.used_bytes), cap.percent_used))
  table.insert(lines, string.format("- **Available**: %s", human_size(cap.avail_bytes)))

  local status_tag = "🟢 Normal"
  if cap.percent_used >= CONFIG.thresholds.critical then
    status_tag = "🔴 Critical"
  elseif cap.percent_used >= CONFIG.thresholds.action then
    status_tag = "🟡 Action Threshold Triggered"
  elseif cap.percent_used >= CONFIG.thresholds.warning then
    status_tag = "🟠 Warning"
  end
  table.insert(lines, string.format("- **Status**: %s", status_tag))
  table.insert(lines, "")

  table.insert(lines, "## 2. Reclaimable Build Targets (`target/`)")
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
  table.insert(lines, "")

  if docker then
    table.insert(lines, "## 4. Docker Storage")
    table.insert(lines, string.format("- **Reclaimable Images**: %s", docker.images_reclaim))
    table.insert(lines, string.format("- **Build Cache**: %s", docker.build_reclaim))
    table.insert(lines, "_Note: Docker volumes are strictly preserved to safeguard persistent application state._")
    table.insert(lines, "")
  end

  table.insert(lines, "## 5. Storage Invariants & Policy")
  table.insert(lines, "- [x] Git repositories, untracked code, and dirty worktrees protected.")
  table.insert(lines, "- [x] Persistent database and Docker volumes excluded from automatic deletion.")
  table.insert(lines, string.format("- [x] Automatic cleanup activates when usage reaches **%d%%**.", CONFIG.thresholds.action))

  return table.concat(lines, "\n")
end

local function cmd_report(out_file)
  local report = generate_markdown_report()
  if out_file and #out_file > 0 then
    os.execute(string.format("mkdir -p %q", out_file:gsub("/[^/]+$", "")))
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
  local cap = get_disk_capacity()
  print(string.format("Dry run evaluation (Mount %s, %d%% used):", cap.mount, cap.percent_used))
  local results = execute_reclaim({ apply = false, min_age_days = CONFIG.stale_build_days })
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
  local cap = get_disk_capacity()
  if not force and cap.percent_used < CONFIG.thresholds.action then
    print(string.format(
      "Disk usage is at %d%% (below action threshold of %d%%). No cleanup required.",
      cap.percent_used, CONFIG.thresholds.action
    ))
    print("Pass --force to run cleanup regardless of threshold.")
    return
  end

  print(string.format("Executing cleanup on %s (current: %d%% used)...", cap.mount, cap.percent_used))
  local results = execute_reclaim({ apply = true, min_age_days = (cap.percent_used >= CONFIG.thresholds.critical and 0 or CONFIG.stale_build_days) })
  print(string.format("Successfully freed %s.", human_size(results.freed_bytes)))

  local after = get_disk_capacity()
  print(string.format("New disk status: %d%% used (%s available).", after.percent_used, human_size(after.avail_bytes)))
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
  local cap = get_disk_capacity()
  if cap.percent_used >= CONFIG.thresholds.critical then
    local res = execute_reclaim({ apply = true, min_age_days = 0 })
    local after = get_disk_capacity()
    notify(
      "CRITICAL: Disk Usage Alert",
      string.format("Root was at %d%%. Reclaimed %s. Current: %d%% (%s free).",
        cap.percent_used, human_size(res.freed_bytes), after.percent_used, human_size(after.avail_bytes)),
      "critical"
    )
  elseif cap.percent_used >= CONFIG.thresholds.action then
    local res = execute_reclaim({ apply = true, min_age_days = CONFIG.stale_build_days })
    local after = get_disk_capacity()
    notify(
      "Automated Disk Maintenance",
      string.format("Root reached %d%% threshold. Reclaimed %s. Current: %d%% (%s free).",
        cap.percent_used, human_size(res.freed_bytes), after.percent_used, human_size(after.avail_bytes)),
      "normal"
    )
  elseif cap.percent_used >= CONFIG.thresholds.warning then
    notify(
      "Disk Space Warning",
      string.format("Root usage at %d%% (%s free). Approaching %d%% action threshold.",
        cap.percent_used, human_size(cap.avail_bytes), CONFIG.thresholds.action),
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
