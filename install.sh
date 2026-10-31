#!/usr/bin/env bash
# omarchy-matrix installer: theme, bar/launcher plugins, hooks, screensaver, fonts, configs.
#
#   ./install.sh                 install (or update) and activate the matrix theme
#   ./install.sh --no-activate   install files only; don't switch theme / restart anything
#   ./install.sh --dry-run       print what would happen, change nothing
#   ./install.sh --no-looknfeel  leave ~/.config/hypr/looknfeel.lua alone
#   ./install.sh --no-autohide   keep the top bar always visible (bar.autoHide=false)
#   ./install.sh --uninstall     undo the most recent install from its backup
#
# Everything is written under $HOME only (never /usr/share/omarchy, never sudo).
# Each install that changes something records a backup + manifest in
# ~/.cache/omarchy-matrix-backup/<timestamp>/ so --uninstall can put things back.
# Re-running is safe: files that are already identical are skipped.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$HOME/.cache/omarchy-matrix-backup"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/$STAMP"
MANIFEST="$BACKUP/manifest"

DRY=0 ACTIVATE=1 LOOKNFEEL=1 AUTOHIDE=1 MODE=install
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY=1 ;;
    --no-activate) ACTIVATE=0 ;;
    --no-looknfeel) LOOKNFEEL=0 ;;
    --no-autohide) AUTOHIDE=0 ;;
    --uninstall) MODE=uninstall ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
  esac
done

if [[ -t 1 ]]; then G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' N=$'\e[0m'; else G='' Y='' R='' N=''; fi
say()  { printf '%s==>%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!!%s  %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%sxx%s  %s\n' "$R" "$N" "$*" >&2; exit 1; }
run()  { if ((DRY)); then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root"
[[ -n ${HOME:-} && -d $HOME ]] || die "\$HOME is not set"

# Refuse anything outside $HOME (and specifically /usr/share/omarchy).
guard() {
  case "$1" in
    "$HOME"/*) ;;
    *) die "refusing to write outside \$HOME: $1" ;;
  esac
  case "$1" in /usr/share/omarchy*) die "refusing to write to $1" ;; esac
}

rel() { printf '%s' "${1#"$HOME"/}"; }

STARTED=0
start_backup() {
  ((STARTED)) && return 0
  STARTED=1
  ((DRY)) && return 0
  mkdir -p "$BACKUP"
  printf '# omarchy-matrix install %s from %s\n' "$STAMP" "$HERE" > "$MANIFEST"
}

# same <src> <dest>: true when dest already matches src (content + symlinks).
# Local backup cruft (*.bak*, *.canvas, *-pre-*) in an installed copy is ignored.
# A symlinked config file whose target already has identical content counts as
# up to date, so the link (e.g. into a dotfiles repo) is left alone.
same() {
  [[ -e $2 || -L $2 ]] || return 1
  if [[ -L $2 && ! -L $1 && -f $1 ]]; then cmp -s "$1" "$2"; return; fi
  [[ -L $2 && ! -L $1 ]] && return 1
  diff -rq --no-dereference -x '*.bak*' -x '.bak-*' -x '*.canvas' -x '*-pre-*' "$1" "$2" >/dev/null 2>&1
}

# put <src> <dest>: back up whatever is at dest, then copy src there.
# A symlink at dest is backed up as the link itself and replaced by a real
# file/dir, so we never write through a link into some other repo.
put() {
  local src="$1" dest="$2"
  guard "$dest"
  [[ -e $src || -L $src ]] || die "missing in repo: $src"
  if same "$src" "$dest"; then printf '    = %s\n' "$(rel "$dest")"; return 0; fi
  start_backup
  if [[ -e $dest || -L $dest ]]; then
    printf '    ~ %s%s\n' "$(rel "$dest")" "$([[ -L $dest ]] && echo " (was a symlink -> $(readlink "$dest"); replaced by a real file)")"
    if ((!DRY)); then
      mkdir -p "$BACKUP/files/$(dirname "$(rel "$dest")")"
      mv "$dest" "$BACKUP/files/$(rel "$dest")"
      printf 'R\t%s\n' "$(rel "$dest")" >> "$MANIFEST"
    fi
  else
    printf '    + %s\n' "$(rel "$dest")"
    ((DRY)) || printf 'N\t%s\n' "$(rel "$dest")" >> "$MANIFEST"
  fi
  run mkdir -p "$(dirname "$dest")"
  run cp -a "$src" "$dest"
}

# ---------------------------------------------------------------- uninstall
uninstall() {
  local last="" cand
  for cand in "$BACKUP_ROOT"/*/; do  # glob order is sorted, so the newest stamp wins
    cand="${cand%/}"
    [[ $cand == *.uninstalled || ! -f $cand/manifest ]] && continue
    last="$cand"
  done
  [[ -n $last ]] || die "no install backup found in $BACKUP_ROOT"
  say "Restoring from $last"
  # Put the branding links back and stop the rain while the theme files still exist.
  local hook="$HOME/.config/omarchy/hooks/theme-set.d/matrix-branding"
  [[ -x $hook ]] && run "$hook" none || true
  local rain="$HOME/.config/omarchy/themes/matrix/rain/matrix-rain"
  [[ -x $rain ]] && run "$rain" stop >/dev/null 2>&1 || true
  local kind path
  tac "$last/manifest" | while IFS=$'\t' read -r kind path; do
    [[ $kind == R || $kind == N ]] || continue
    [[ -n $path && $path != /* && $path != *..* ]] || { warn "skipping odd manifest entry: $path"; continue; }
    guard "$HOME/$path"
    run rm -rf "$HOME/$path"
    if [[ $kind == R ]]; then
      printf '    < %s\n' "$path"
      run mkdir -p "$(dirname "$HOME/$path")"
      run cp -a "$last/files/$path" "$HOME/$path"
    else
      printf '    - %s\n' "$path"
    fi
  done
  ((DRY)) || mv "$last" "$last.uninstalled"
  command -v fc-cache >/dev/null && run fc-cache -f >/dev/null 2>&1 || true
  if ((ACTIVATE)); then
    if [[ $(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null) == matrix ]]; then
      warn "matrix is still the active theme name; pick another with: omarchy-theme-set <name>"
    fi
    command -v omarchy-restart-shell >/dev/null && run omarchy-restart-shell || true
    command -v hyprctl >/dev/null && run hyprctl reload || true
  fi
  say "Uninstalled."
}

# ---------------------------------------------------------------- deps
check_deps() {
  local missing=0 c
  for c in hyprctl quickshell omarchy-shell omarchy-theme-set omarchy-restart-shell; do
    command -v "$c" >/dev/null 2>&1 || { warn "required command not found: $c"; missing=1; }
  done
  if ((missing)); then
    if ((ACTIVATE)) && ((!DRY)); then die "this needs an Omarchy install (Hyprland + omarchy-shell/Quickshell); use --no-activate to only copy files"; fi
    warn "continuing without activation checks"
  fi
  [[ -f $HOME/.config/hypr/hyprland.lua ]] || warn "$HOME/.config/hypr/hyprland.lua not found: the theme targets Omarchy's Lua Hyprland config (Hyprland >= 0.56)"
  command -v jq >/dev/null 2>&1 || warn "jq not found: shell.json will be replaced instead of merged"
  command -v fc-cache >/dev/null 2>&1 || warn "fc-cache not found: run it yourself after install so the font is picked up"
  command -v ghostty >/dev/null 2>&1 || warn "ghostty not found: its config is installed anyway"
  # Shaders ship compiled (*.qsb); qsb is only needed if you edit a .frag.
  return 0
}

# shell.json: keep the user's file, but take this setup's bar settings (bar.id =
# sveinn.bar with autoHide, layout) and make sure omarchy.menu is disabled so the
# launcher routes to sveinn.menu. --no-autohide turns bar.autoHide off.
install_shell_json() {
  local src="$HERE/config/omarchy/shell.json" dest="$HOME/.config/omarchy/shell.json" srctmp=""
  if ((!AUTOHIDE)); then
    if command -v jq >/dev/null 2>&1; then
      srctmp="$(mktemp)"
      jq '.bar.autoHide = false' "$src" > "$srctmp"
      src="$srctmp"
      printf '    (--no-autohide: bar.autoHide = false)\n'
    else
      warn "--no-autohide needs jq; set \"autoHide\": false under \"bar\" in ~/.config/omarchy/shell.json yourself"
    fi
  fi
  if [[ -f $dest && ! -L $dest ]] && command -v jq >/dev/null 2>&1 && jq -e . "$dest" >/dev/null 2>&1; then
    local tmp
    tmp="$(mktemp)"
    jq -s '
      .[0] as $u | .[1] as $m
      | $u
      | .bar = (($u.bar // {}) * $m.bar)
      | .bar.layout = $m.bar.layout
      | .disabledPlugins = ((($u.disabledPlugins // []) + ($m.disabledPlugins // [])) | unique)
      | .cloneSourceRestores = ((($u.cloneSourceRestores // []) + ($m.cloneSourceRestores // [])) | unique)
      | .version = ($u.version // $m.version)
    ' "$dest" "$src" > "$tmp"
    printf '    (merged bar settings/layout + disabledPlugins into your shell.json)\n'
    put "$tmp" "$dest"
    rm -f "$tmp"
  else
    put "$src" "$dest"
  fi
  [[ -z $srctmp ]] || rm -f "$srctmp"
}

install_all() {
  check_deps
  ((DRY)) && say "Dry run: nothing will be changed"

  say "Theme -> ~/.config/omarchy/themes/matrix"
  put "$HERE/theme" "$HOME/.config/omarchy/themes/matrix"

  say "Bar widgets + launcher plugins -> ~/.config/omarchy/plugins"
  local p
  for p in "$HERE"/plugins/*/; do p="${p%/}"; put "$p" "$HOME/.config/omarchy/plugins/$(basename "$p")"; done

  say "Hooks -> ~/.config/omarchy/hooks"
  local h d
  for d in "$HERE"/hooks/*/; do
    d="${d%/}"
    for h in "$d"/*; do put "$h" "$HOME/.config/omarchy/hooks/$(basename "$d")/$(basename "$h")"; done
  done

  say "Screensaver override -> ~/.local/bin"
  local b
  for b in "$HERE"/bin/*; do
    put "$b" "$HOME/.local/bin/$(basename "$b")"
    run chmod +x "$HOME/.local/bin/$(basename "$b")"
  done
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) warn "$HOME/.local/bin is not on PATH; the matrix screensaver override won't be used" ;; esac

  say "Shell config (bar layout, launcher = sveinn.menu)"
  install_shell_json

  if ((LOOKNFEEL)); then
    say "Hyprland look'n'feel (gaps) -> ~/.config/hypr/looknfeel.lua"
    put "$HERE/config/hypr/looknfeel.lua" "$HOME/.config/hypr/looknfeel.lua"
  fi

  say "Fonts, fontconfig, terminal, GTK"
  put "$HERE/fonts/HurmitNerdFont" "$HOME/.local/share/fonts/HurmitNerdFont"
  put "$HERE/config/fontconfig/fonts.conf" "$HOME/.config/fontconfig/fonts.conf"
  put "$HERE/config/ghostty/config" "$HOME/.config/ghostty/config"
  put "$HERE/config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
  put "$HERE/config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
  if command -v fc-cache >/dev/null 2>&1; then run fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || warn "fc-cache failed"; fi

  if ((STARTED)) && ((!DRY)); then say "Backup of replaced files: $BACKUP"; fi
  ((STARTED)) || say "Everything already up to date."

  if ((ACTIVATE)); then
    say "Activating"
    run omarchy-theme-set matrix
    run omarchy-restart-shell || warn "omarchy-restart-shell failed"
    run hyprctl reload || warn "hyprctl reload failed"
  else
    say "Not activated. Run: omarchy-theme-set matrix && omarchy-restart-shell"
  fi
}

if [[ $MODE == uninstall ]]; then uninstall; else install_all; fi
