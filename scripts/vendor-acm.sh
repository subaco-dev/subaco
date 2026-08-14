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
#   - 取得元は環境変数で上書き可能。既定値は確定済み（下記）。
#
# 確定済みの取得元（v0.1.1 で照合済み）:
#   - リポジトリ: ponponusa/agent-context-maintainer
#   - 単一ファイル: scripts/agent_context.py（依存フリー・Python 3.9+）
#   - 生成マーカー: `<!-- agent-context-maintainer:begin -->` / `:end -->`（実体と照合済み）
#   - あわせて LICENSE（MIT）も同梱する（vendored copy の再配布条件）。
#
# 使い方:
#   bash scripts/vendor-acm.sh            # 既定座標（v0.1.1）から取得
#   ACM_REF=v0.2.0 bash scripts/vendor-acm.sh
#   ACM_REPO=owner/repo ACM_FILE=tool.py bash scripts/vendor-acm.sh
set -euo pipefail

# --- 取得元（環境変数で上書き可） ---
ACM_REPO="${ACM_REPO:-ponponusa/agent-context-maintainer}"
ACM_REF="${ACM_REF:-v0.1.1}"
# a-c-m の単一ファイル（リポジトリ内パス。配置先はベース名のみを使う）。
ACM_FILE="${ACM_FILE:-scripts/agent_context.py}"
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

# 取得ヘルパー: URL を一時ファイルへ落とし、健全性を確認してから原子的に配置する。
fetch() {
  src_url=$1
  dest_path=$2
  tmp="$(mktemp "${TMPDIR:-/tmp}/acm.XXXXXX")"
  if curl -fLsS "$src_url" -o "$tmp"; then
    # 空ファイル・HTML エラーページを掴んでいないか最低限の健全性チェック。
    if [ ! -s "$tmp" ]; then
      rm -f "$tmp"
      warn "取得結果が空です: $src_url（既存 vendor/ は更新しません）。"
      return 1
    fi
    mv "$tmp" "$dest_path"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

url="${ACM_BASE_URL}/${ACM_FILE}"
dest="$vendor_dir/${ACM_FILE##*/}"

log "取得します: $url"
if fetch "$url" "$dest"; then
  # 実行属性が要るエントリ形態にも備えて +x を付す（Python 単一ファイルでも無害）。
  chmod +x "$dest" 2>/dev/null || true
  log "配置しました: $dest"
  # LICENSE（MIT）も同梱する（失敗しても本体は有効 — best-effort）。
  if fetch "${ACM_BASE_URL}/LICENSE" "$vendor_dir/LICENSE"; then
    log "配置しました: $vendor_dir/LICENSE"
  else
    warn "LICENSE の取得に失敗しました（本体は取得済み。必要なら手動で配置してください）。"
  fi
  log "agent-context ラッパーが上方探索でこの vendor/ を解決します。"
  exit 0
fi

warn "取得に失敗しました（URL・ネットワーク・ACM_* を確認してください）。vendor/ は更新しません。"
warn "  URL: $url"
exit 1
