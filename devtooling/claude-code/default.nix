{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    claude-code.enable = lib.mkEnableOption "Enable Claude Code CLI module";
  };

  config = lib.mkIf config.claude-code.enable {
    home.packages = with pkgs; [ pkgs.claude-code ];

    home.file.".claude/CLAUDE.md".text = ''
      # Claude Code Global Style

      Enforce consistent output and behavior across all projects. Project-specific rules may extend these defaults.

      ## Error Handling

      When a command or task fails, report the error and ask for guidance. Surface blockers rather than documenting hypothetical outcomes. Do not generate documentation files as workarounds for failed execution.

      ## Artifact Discipline

      Prefer chat responses over file creation for plans, status updates, and explanations. Create files only when they are source code, configuration, or explicitly requested artifacts.

      ## Environment

      This is a NixOS system. Use `docker compose` (space, not hyphen). Binary paths may differ from standard distributions. Ask about missing commands rather than assuming paths.

      ## Response Format

      Write plain text responses. Keep them brief and direct. Use line breaks for separation. Code blocks and command examples are acceptable.

      Avoid emojis and symbols (no checkmarks, arrows, or decorations). Avoid decorative formatting (bold, italics, boxes). Avoid bullet points in prose (acceptable in technical lists).

      Bad: "Phase 1 passed successfully. **Ready for Phase 2:**"
      Good: "Phase 1 passed. Ready for Phase 2."

      ## Commit Messages

      Follow Conventional Commits: https://www.conventionalcommits.org/

      Structure:
      ```
      <type>[scope]: description

      [optional body]
      ```

      Types: feat, fix, docs, style, refactor, perf, test, build, chore, ci

      Rules: Imperative mood ("add" not "added"). Subject under 72 characters, no trailing period. Body explains WHY, wrapped at 100 chars. No emojis, bullets, or AI attribution.

      Examples:
      ```
      feat(auth): add passwordless sudo rule

      Use NOPASSWD option with command path /run/current-system/sw/bin/cmd
      to enable passwordless execution for administrative tasks.
      ```

      ```
      fix: correct keybind escape sequence
      ```

      ## Documentation Standards

      File naming: Use lowercase with hyphens (readme.md, changelog.md, setup-guide.md). Avoid ALL CAPS filenames.

      Creation rules: Create documentation only when explicitly requested. Keep documentation minimal and focused. Prefer inline code comments over separate documentation files.

      ## Dependency Management

      Check project-specific rules for dependency commands. Common patterns:

      Python projects: Use uv (uv add, uv remove) rather than pip.
      Node projects: Use the project's package manager (bun, pnpm, npm).
      Nix projects: Add packages to the appropriate .nix file.
      Docker services: Modify docker-compose.yml.

      Inspect the environment before adding dependencies.

      ## General Notes

      Keep output brief. Prioritize clarity over completeness. When in doubt, prefer fewer words.
    '';
  };
}
