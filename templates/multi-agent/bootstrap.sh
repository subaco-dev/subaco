#!/usr/bin/env bash
# bootstrap.sh (multi-agent) — テンプレート展開直後に一度だけ実行する初期化スクリプト。
#
# 手順:
#   1) プロジェクト名の置換
#   2) agent-context scaffold . --agent auto
#   3) チーム名の導出（hive-team → .hive/team 0600）と .cube 初期化
#   4) uv lock
#   5) git init
#   6) オプトイン導線（trusted_agents 案内 / allow_shared_kernel 対話 — --ci でスキップ）
#
# 非対話 --ci フラグ（smoke 用）で 6) の対話を全てスキップする。
# 前提: `direnv allow`（または `nix develop`）で devShell に入った状態で実行する。
set -euo pipefail

# --- 引数解析 ---
CI_MODE=0
for arg in "$@"; do
  case "$arg" in
  --ci) CI_MODE=1 ;;
  -h | --help)
    cat <<'EOF'
使い方: ./bootstrap.sh [--ci]
  --ci   非対話モード（CI / smoke 用。trusted_agents / allow_shared_kernel の対話導線を出さない）。
EOF
    exit 0
    ;;
  *)
    printf 'bootstrap: 不明な引数: %s\n' "$arg" >&2
    exit 2
    ;;
  esac
done

log() { printf '▶ %s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# trusted_agents 許可リストの作成手順を案内する（bootstrap は生成しない）。
print_trusted_agents_guidance() {
  local team_name=${1:-<team>}
  cat <<EOF

──────────────────────────────────────────────
オプトイン案内 1/2: 信頼メンバー許可リスト（trusted_agents）
──────────────────────────────────────────────
リポジトリ外・エージェント書換不能の設定です（bootstrap は生成しません）。
~/.config/subaco/${team_name}/trusted_agents に、初回 join で trust=1 を付与したい
エージェント名を 1 行 1 件で記載してください（任意で事前共有トークンのハッシュを併記可）。
リスト外の名義は trust=0（未信頼）で参加します。
  例:
    mkdir -p ~/.config/subaco/${team_name}
    printf '%s\n' 'claude-1' 'codex-1' >> ~/.config/subaco/${team_name}/trusted_agents
EOF
}

# 共有カーネル実行のオプトイン。既定は No。承諾時のみ config.toml を作成する。
prompt_allow_shared_kernel() {
  cat <<'EOF'

──────────────────────────────────────────────
オプトイン案内 2/2: 共有カーネル実行の許可（allow_shared_kernel）
──────────────────────────────────────────────
既定の実行プレーン（cube-shim）は未信頼コードを default-deny で扱います。
podman / wslc（共有カーネル層）での実行は、ホスト管理者がリポジトリ外設定
~/.config/subaco-shim/config.toml で明示許可した場合のみ有効になります。
（macOS の Apple Container は vm-per-container のためオプトイン不要です。）
EOF
  printf '共有カーネル実行を許可しますか？（~/.config/subaco-shim/config.toml を作成）[y/N]: '
  local reply=""
  read -r reply || reply=""
  case "$reply" in
  [yY] | [yY][eE][sS])
    local cfg_dir="$HOME/.config/subaco-shim"
    local cfg="$cfg_dir/config.toml"
    mkdir -p "$cfg_dir"
    if [ -f "$cfg" ]; then
      warn "$cfg は既に存在します。内容を確認し、手動で allow_shared_kernel を設定してください。"
    else
      printf '# subaco-shim ホスト設定（リポジトリ外・エージェント書換不能）\nallow_shared_kernel = true\n' >"$cfg"
      chmod 600 "$cfg"
      log "作成しました: $cfg"
    fi
    ;;
  *)
    log "共有カーネル実行は許可しませんでした（既定: default-deny）。後から $HOME/.config/subaco-shim/config.toml で設定できます。"
    ;;
  esac
}

# --- 1) プロジェクト名の置換 ---
project_name=$(basename "$(pwd)")
project_slug=$(printf '%s' "$project_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')
[ -n "$project_slug" ] || project_slug="agent-native-product"

log "プロジェクト名を置換します: name='$project_name' slug='$project_slug'"
if have sd; then
  for f in AGENTS.md pyproject.toml; do
    [ -f "$f" ] || continue
    sd -s '__PROJECT_NAME__' "$project_name" "$f"
    sd -s '__PROJECT_SLUG__' "$project_slug" "$f"
  done
else
  warn "sd が見つからないためプロジェクト名置換をスキップしました（devShell で再実行してください）。"
fi

# --- 2) agent-context scaffold ---
log "エージェント文脈を scaffold します（agent-context scaffold . --agent auto）"
if have agent-context; then
  agent-context scaffold . --agent auto ||
    warn "agent-context scaffold に失敗しました。テンプレート同梱の AGENTS.md 等をそのまま使用します（a-c-m の vendored copy は段階3で確定 — TODO）。"
else
  warn "agent-context が見つかりません。scaffold をスキップします（テンプレート同梱ファイルを使用）。"
fi

# --- 3) チーム名の導出（hive-team → .hive/team）と .cube 初期化 ---
# 正規化は hive-team（lib/hive_team.py）が唯一実装。ここでは呼ぶだけ。
team=""
log "チーム名を導出します（hive-team）"
if have hive-team; then
  if team=$(hive-team); then
    log "チーム名: $team（.hive/team に永続化）"
  else
    warn "hive-team の実行に失敗しました。.hive/team は direnv（.envrc）が生成します。"
  fi
else
  warn "hive-team が見つかりません。.hive/team は direnv（.envrc）が生成します。"
fi
# .cube はシム専用ディレクトリ（.hive とは別・0700・丸ごと gitignore）。
# .envrc も作成するが、bootstrap でも防御的に用意する。
if [ ! -d .cube ]; then
  mkdir -p .cube && chmod 700 .cube
fi

# --- 4) uv lock ---
log "Python 依存をロックします（uv lock）"
if have uv; then
  uv lock || warn "uv lock に失敗しました（ネットワーク接続 / pyproject.toml を確認してください）。"
else
  warn "uv が見つかりません。uv lock をスキップします。"
fi

# --- 5) git init ---
if [ -d .git ]; then
  log "既存の git リポジトリを検出（git init はスキップ）"
elif have git; then
  log "git リポジトリを初期化します（git init）"
  git init -q
else
  warn "git が見つかりません。git init をスキップします。"
fi

# --- 6) オプトイン導線 ---
if [ "$CI_MODE" -eq 1 ]; then
  log "--ci: 対話導線（trusted_agents / allow_shared_kernel）をスキップしました。"
else
  print_trusted_agents_guidance "${team:-<team>}"
  prompt_allow_shared_kernel
fi

log "bootstrap 完了。'direnv reload'（または新しいシェルで 'direnv allow'）で環境を有効化してください。"
