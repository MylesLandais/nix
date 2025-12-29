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

      Enforce consistent commits and output across all projects.

      ## Commit Messages (MANDATORY)

      Follow [Conventional Commits](https://www.conventionalcommits.org/):

      ```
      <type>[scope]: description

      [optional body]
      ```

      Types: feat, fix, docs, style, refactor, perf, test, build, chore, ci

      Rules:
      - Imperative mood: "add" not "added"
      - No trailing period
      - Subject ≤ 72 characters
      - Body explains WHY, wrapped at 100 chars
      - No emojis, bullets, or decorations
      - No AI attribution or "Generated with" footers

      Examples:

      feat(auth): add passwordless sudo rule

      Use NOPASSWD option with command path /run/current-system/sw/bin/cmd
      to enable passwordless execution for administrative tasks.

      fix: correct keybind escape sequence

      ## Response Format (MANDATORY)

      - No emojis: ✓ ✅ ⚠️ 🎉
      - No decorative formatting: bold, italics, boxes
      - No bullet points or lists in prose
      - Plain text, direct and brief
      - Code blocks and commands are fine

      Bad: "✅ Phase 1 passed. **Ready for Phase 2:**"
      Good: "Phase 1 passed. Ready for Phase 2."

      ## Other Notes

      Keep output brief. Prioritize clarity. Reference [Conventional Commits](https://www.conventionalcommits.org/) for edge cases.
    '';
  };
}
