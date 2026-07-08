#!/usr/bin/env bash
# vendor-acm.sh — agent-context-maintainer（a-c-m）の単一ファイルを vendor/ へ取得する。
#
# a-c-m は「単一ファイル」という性質上、flake input ではなく vendored copy + 更新チェック CI が
# 最も摩擦が少ない。本スクリプトは GitHub から a-c-m の単一ファイルを取得し、
# vendor/agent-context-maintainer/ 配下へ置く。devShell の agent-context ラッパー
# （wrappers/agent-context.sh）は PWD から上方探索でこの vendor/ を見つけて委譲する
# （実体の配置に依存しない配置非依存エントリ）。
#
# 方針:
#   - **best-effort**: ネットワーク不通や取得失敗でも既存 vendor/ を壊さない
#     （一時ファイルへ落としてから原子的に mv する）。
#   - このマシン（オフライン前提）では実行しなくてよい。CI や利用者環境で走る。
#   - 取得元は環境変数で上書き可能。既定値は暫定であり、実 URL は取得先確定後に固定する。
#
# TODO(段階3): a-c-m の実リポジトリ座標（org/repo）・ref・単一ファイル名・最終レイアウトを確定し、
#   既定値（ACM_REPO / ACM_REF / ACM_FILE）を実値へ固定する。エントリの実体パスが確定したら
#   wrappers/agent-context.sh の候補列（exec_acm）もそれに合わせて絞る。
#
# 使い方:
#   bash scripts/vendor-acm.sh            # 既定座標から取得
#   ACM_REF=v1.2.3 bash scripts/vendor-acm.sh
#   ACM_REPO=owner/repo ACM_FILE=tool.py bash scripts/vendor-acm.sh
set -euo pipefail

# --- 取得元（環境変数で上書き可。既定は暫定 — 上記 TODO） ---
ACM_REPO="${ACM_REPO:-ponponusa/agent-context-maintainer}"
ACM_REF="${ACM_REF:-main}"
# a-c-m の単一ファイル名。実名は取得先確定後に固定する。
ACM_FILE="${ACM_FILE:-agent_context_maintainer.py}"
# raw 取得 URL（GitHub raw。ミラー利用時は ACM_BASE_URL で上書き）。
ACM_BASE_URL="${ACM_BASE_URL:-https://raw.githubusercontent.com/${ACM_REPO}/${ACM_REF}}"

# --- 配置先（このスクリプトの位置からリポジトリルートを解決し vendor/ を置く） ---
script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(dirname "$script_dir")     # scripts/ の親をリポジトリルートとみなす
vendor_dir="$repo_root/vendor/agent-context-maintainer"

log() { printf '▶ vendor-acm: %s\n' "$*" >&2; }
warn() { printf '⚠ vendor-acm: %s\n' "$*" >&2; }

if ! command -v curl >/dev/null 2>&1; then
  warn "curl が見つかりません。a-c-m の取得をスキップします（best-effort）。"
  warn "手動取得: ${ACM_BASE_URL}/${ACM_FILE} を ${vendor_dir}/ へ配置してください。"
  exit 1
fi

mkdir -p "$vendor_dir"

url="${ACM_BASE_URL}/${ACM_FILE}"
dest="$vendor_dir/${ACM_FILE##*/}"
tmp="$(mktemp "${TMPDIR:-/tmp}/acm.XXXXXX")"
# シェル終了時に一時ファイルを掃除する。
trap 'rm -f "$tmp"' EXIT

log "取得します: $url"
# -f: HTTP エラーで失敗扱い / -L: リダイレクト追従 / -s: 進捗抑制 / -S: エラーは表示。
if curl -fLsS "$url" -o "$tmp"; then
  # 空ファイル・HTML エラーページを掴んでいないか最低限の健全性チェック。
  if [ ! -s "$tmp" ]; then
    warn "取得結果が空です。vendor/ は更新しません（best-effort）。"
    exit 1
  fi
  mv "$tmp" "$dest"
  trap - EXIT
  # 実行属性が要るエントリ形態にも備えて +x を付す（Python 単一ファイルでも無害）。
  chmod +x "$dest" 2>/dev/null || true
  log "配置しました: $dest"
  log "agent-context ラッパーが上方探索でこの vendor/ を解決します。"
  exit 0
fi

warn "取得に失敗しました（URL・ネットワーク・ACM_* を確認してください）。vendor/ は更新しません。"
warn "  URL: $url"
warn "  実 URL / 単一ファイル名は段階3で確定します（本スクリプト冒頭の TODO 参照）。"
exit 1
