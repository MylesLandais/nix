# shellcheck shell=bash
# render_unattend SRC DST — copy an autounattend.xml, replacing the
# @GUEST_PASSWORD@ placeholder with $WIN_GUEST_PASSWORD (XML-escaped). The
# committed template carries no password; a template that contains the
# placeholder fails without the variable instead of falling back to a default.
render_unattend() {
  local src=$1 dst=$2 pw content
  if ! grep -q '@GUEST_PASSWORD@' "$src"; then
    cp "$src" "$dst"
    return
  fi
  : "${WIN_GUEST_PASSWORD:?set WIN_GUEST_PASSWORD to the Windows guest account password}"
  # Literal replacements: "&" in a replacement must not mean "the match".
  shopt -u patsub_replacement 2>/dev/null || true
  pw=${WIN_GUEST_PASSWORD//&/&amp;}
  pw=${pw//</&lt;}
  pw=${pw//>/&gt;}
  content=$(<"$src")
  printf '%s\n' "${content//@GUEST_PASSWORD@/$pw}" >"$dst"
}
