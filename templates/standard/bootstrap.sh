#!/usr/bin/env bash
# bootstrap.sh (standard) — テンプレート展開直後に一度だけ実行する初期化スクリプト。
#
# 手順: プロジェクト名の置換 → a-c-m vendor 取得（不在時） → agent-context scaffold → uv lock → git init。
# 非対話 --ci フラグ（smoke 用）で対話を全てスキップする（standard は現状 対話なし）。
#
# 前提: `direnv allow`（または `nix develop`）で devShell に入った状態で実行する
#       （rg / sd / git / uv / agent-context などが PATH に載る）。
set -euo pipefail

# --- 引数解析 ---
CI_MODE=0
for arg in "$@"; do
  case "$arg" in
  --ci) CI_MODE=1 ;;
  -h | --help)
    cat <<'EOF'
使い方: ./bootstrap.sh [--ci]
  --ci   非対話モード（CI / smoke 用。対話プロンプトを出さない）。
EOF
    exit 0
    ;;
  *)
    printf 'bootstrap: 不明な引数: %s\n' "$arg" >&2
    exit 2
    ;;
  esac
done
# CI_MODE は standard では現状 未使用（対話導線なし）。multi-agent との API 整合のため受理する。
: "$CI_MODE"

log() { printf '▶ %s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*" >&2; }

# 必須コマンドの存在確認（devShell 外実行の検知）。
have() { command -v "$1" >/dev/null 2>&1; }

# --- 1) プロジェクト名の置換 ---
project_name=$(basename "$(pwd)")
# パッケージ名スラグ: 小文字化し [a-z0-9._-] 以外を - へ（PyPI / uv 命名規則に寄せる）。
project_slug=$(printf '%s' "$project_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')
[ -n "$project_slug" ] || project_slug="agent-native-product"

log "プロジェクト名を置換します: name='$project_name' slug='$project_slug'"
if have sd; then
  # __PROJECT_NAME__（表示名）/ __PROJECT_SLUG__（パッケージ名）を置換（存在するファイルのみ）。
  for f in AGENTS.md pyproject.toml; do
    [ -f "$f" ] || continue
    sd -s '__PROJECT_NAME__' "$project_name" "$f"
    sd -s '__PROJECT_SLUG__' "$project_slug" "$f"
  done
else
  warn "sd が見つからないためプロジェクト名置換をスキップしました（devShell で再実行してください）。"
fi

# --- 1.5) a-c-m の vendored copy 取得（不在時のみ・best-effort） ---
if [ ! -f vendor/agent-context-maintainer/agent_context.py ] && [ -f scripts/vendor-acm.sh ]; then
  log "a-c-m の vendored copy を取得します（scripts/vendor-acm.sh）"
  bash scripts/vendor-acm.sh ||
    warn "a-c-m の取得に失敗しました（オフライン等）。scaffold はスキップされます（後で再実行可）。"
fi

# --- 2) agent-context scaffold ---
# テンプレート同梱の .agents/core.md 等は生成マーカーを持たない手書きファイルのため、
# --append-generated-block で「手書き内容を保全しつつ管理ブロックを追記」する
# （素の scaffold はマーカー不在を理由に拒否する）。再実行は冪等（ブロック内のみ更新）。
log "エージェント文脈を scaffold します（agent-context scaffold . --agent auto --append-generated-block）"
if have agent-context; then
  agent-context scaffold . --agent auto --append-generated-block ||
    warn "agent-context scaffold に失敗しました。テンプレート同梱の AGENTS.md 等をそのまま使用します。"
else
  warn "agent-context が見つかりません。scaffold をスキップします（テンプレート同梱ファイルを使用）。"
fi

# --- 3) uv lock ---
log "Python 依存をロックします（uv lock）"
if have uv; then
  uv lock || warn "uv lock に失敗しました（ネットワーク接続 / pyproject.toml を確認してください）。"
else
  warn "uv が見つかりません。uv lock をスキップします。"
fi

# --- 4) git init ---
if [ -d .git ]; then
  log "既存の git リポジトリを検出（git init はスキップ）"
elif have git; then
  log "git リポジトリを初期化します（git init）"
  git init -q
else
  warn "git が見つかりません。git init をスキップします。"
fi

log "bootstrap 完了。'direnv reload'（または新しいシェルで 'direnv allow'）で環境を有効化してください。"
