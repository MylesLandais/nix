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

      ## Documentation Standards (MANDATORY)

      File naming rules:
      - NEVER use ALL CAPS filenames (README.md, CHANGELOG.md, CONTRIBUTING.md, LICENSE.md)
      - Use lowercase with hyphens: readme.md, changelog.md, contributing.md, license.md
      - Prefer descriptive lowercase names: setup-guide.md, api-reference.md

      Documentation creation rules:
      - NEVER create documentation files unless explicitly requested
      - Do not proactively generate readme files, changelogs, or contributing guides
      - Avoid cluttering repositories with boilerplate documentation
      - If documentation is needed, keep it minimal and focused
      - Prefer inline code comments over separate documentation files when appropriate

      Bad filenames: README.md, CHANGELOG.md, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md
      Good filenames: readme.md, changelog.md, contributing.md, security.md, code-of-conduct.md

      ## Other Notes

      Keep output brief. Prioritize clarity. Reference [Conventional Commits](https://www.conventionalcommits.org/) for edge cases.
    '';
  };
}
