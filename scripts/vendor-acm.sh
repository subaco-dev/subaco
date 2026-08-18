#!/usr/bin/env bash
# vendor-acm.sh — agent-context-maintainer（a-c-m）の単一ファイルを vendor/ へ取得・検証する。
#
# a-c-m は「単一ファイル」という性質上、flake input ではなく vendored copy + 検証 CI が
# 最も摩擦が少ない。本スクリプトは GitHub から a-c-m の単一ファイルを取得し、
# vendor/agent-context-maintainer/ 配下へ置く。devShell の agent-context ラッパー
# （wrappers/agent-context.sh）は PWD から上方探索でこの vendor/ を見つけて委譲する。
#
# 検証セマンティクス（CI ゲートとしての要件）:
#   - 取得元は**可変タグではなく commit SHA に固定**し、取得物は **sha256 checksum で検証**する。
#   - **既存の vendor は上書きしない**: 存在する場合は checksum を照合し、一致なら成功（スキップ）、
#     不一致なら**エラー終了**（改変・破損の検出。上書きで隠蔽しない——CI がこの失敗で止まる）。
#   - 座標を環境変数で上書きした場合（ACM_REPO/ACM_REF/ACM_FILE のいずれか）、既定 checksum は
#     適用されず **ACM_SHA256 の併記が必須**（未指定は即エラー。検証なしの取得や、旧 vendor を
#     「一致」と誤報して成功扱いにする経路を残さない）。LICENSE_SHA256 のみ任意（best-effort）。
#   - 意図的な更新は「旧 vendor を削除 → 新座標 + ACM_SHA256 で取得 → DEFAULT_* を更新して
#     コミット」の手順で行う（vendor/agent-context-maintainer/README.md 参照）。
#
# 確定済みの取得座標（v0.1.1 = commit 25354c9 で照合済み）:
#   - リポジトリ: ponponusa/agent-context-maintainer
#   - 単一ファイル: scripts/agent_context.py（依存フリー・Python 3.9+）
#   - 生成マーカー: `<!-- agent-context-maintainer:begin -->` / `:end -->`（実体と照合済み）
#   - あわせて LICENSE（MIT）も同梱する（vendored copy の再配布条件）。
#
# 使い方:
#   bash scripts/vendor-acm.sh            # 既定座標から取得 or 既存 vendor の検証
#   rm -f vendor/agent-context-maintainer/agent_context.py &&
#     ACM_REF=<commit-sha> ACM_SHA256=<hex> bash scripts/vendor-acm.sh   # 意図的な更新時
set -euo pipefail

# --- 既定座標（更新時は 4 点セットで上書き・確定する） ---
DEFAULT_ACM_REPO="ponponusa/agent-context-maintainer"
DEFAULT_ACM_REF="25354c94db194f9c09bfaa3108542e9674325c7b" # v0.1.1（タグは可変のため commit SHA 固定）
DEFAULT_ACM_FILE="scripts/agent_context.py"
DEFAULT_ACM_SHA256="f2552bb600ac321c0356fb03452f68991a2ff6fa889a3128f71f299850f03fa8"
DEFAULT_LICENSE_SHA256="0bbfe74cbf79c82c53b06045ba2ed7dbf32c3bff7ae0618e334529e08de5710d"

ACM_REPO="${ACM_REPO:-$DEFAULT_ACM_REPO}"
ACM_REF="${ACM_REF:-$DEFAULT_ACM_REF}"
ACM_FILE="${ACM_FILE:-$DEFAULT_ACM_FILE}"
ACM_BASE_URL="${ACM_BASE_URL:-https://raw.githubusercontent.com/${ACM_REPO}/${ACM_REF}}"

# 座標が既定のままのときだけ既定 checksum を適用する。座標を一つでも上書きした場合は
# ACM_SHA256 を必須とする（未指定だと「検証スキップ→既存 v0.1.1 を一致と誤報して rc=0」
# という無検証成功の経路になるため、ここで即エラーにする）。
if [ "$ACM_REPO" = "$DEFAULT_ACM_REPO" ] && [ "$ACM_REF" = "$DEFAULT_ACM_REF" ] && [ "$ACM_FILE" = "$DEFAULT_ACM_FILE" ]; then
  ACM_SHA256="${ACM_SHA256:-$DEFAULT_ACM_SHA256}"
  LICENSE_SHA256="${LICENSE_SHA256:-$DEFAULT_LICENSE_SHA256}"
elif [ -z "${ACM_SHA256:-}" ]; then
  printf '✗ vendor-acm: 座標（ACM_REPO/ACM_REF/ACM_FILE）を上書きした場合は ACM_SHA256 の指定が必須です。\n' >&2
  printf '  例: ACM_REF=<commit-sha> ACM_SHA256=<新ファイルの sha256> bash scripts/vendor-acm.sh\n' >&2
  exit 1
else
  LICENSE_SHA256="${LICENSE_SHA256:-}"
fi

# --- 配置先（このスクリプトの位置からリポジトリルートを解決し vendor/ を置く） ---
script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(dirname "$script_dir") # scripts/ の親をリポジトリルートとみなす
vendor_dir="$repo_root/vendor/agent-context-maintainer"

log() { printf '▶ vendor-acm: %s\n' "$*" >&2; }
warn() { printf '⚠ vendor-acm: %s\n' "$*" >&2; }
die() {
  printf '✗ vendor-acm: %s\n' "$*" >&2
  exit 1
}

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi
}

# checksum 検証。期待値が空ならスキップして 0 を返す——本体（ACM_SHA256）は座標上書き時に
# 必須化済みのため、この経路に到達するのは任意の LICENSE_SHA256 のみ。
verify_sha256() {
  path=$1
  expected=$2
  what=$3
  if [ -z "$expected" ]; then
    warn "$what の checksum 検証をスキップします（LICENSE_SHA256 未指定・best-effort）。"
    return 0
  fi
  actual=$(sha256_of "$path")
  if [ "$actual" != "$expected" ]; then
    warn "$what の checksum 不一致: expected=$expected actual=$actual"
    return 1
  fi
  return 0
}

dest="$vendor_dir/${ACM_FILE##*/}"

# --- 既存 vendor がある場合: 上書きせず検証のみ（改変検出は CI 失敗として表面化させる） ---
if [ -f "$dest" ]; then
  if verify_sha256 "$dest" "$ACM_SHA256" "既存 vendor ($dest)"; then
    log "既存 vendor は期待 checksum と一致（取得スキップ）: $dest"
    exit 0
  fi
  die "既存 vendor が期待 checksum と不一致です。改変・破損の可能性があるため上書きしません。意図的な更新なら vendor を削除して再実行するか、既定座標（DEFAULT_ACM_*）を更新してください。"
fi

# --- 取得（vendor 不在時のみ） ---
command -v curl >/dev/null 2>&1 || die "curl が見つかりません。手動取得: ${ACM_BASE_URL}/${ACM_FILE} を ${vendor_dir}/ へ。"
mkdir -p "$vendor_dir"

fetch_verified() {
  src_url=$1
  dest_path=$2
  expected=$3
  what=$4
  tmp="$(mktemp "${TMPDIR:-/tmp}/acm.XXXXXX")"
  if ! curl -fLsS "$src_url" -o "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    warn "取得結果が空です: $src_url"
    return 1
  fi
  if ! verify_sha256 "$tmp" "$expected" "$what"; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$dest_path"
  return 0
}

url="${ACM_BASE_URL}/${ACM_FILE}"
log "取得します: $url"
fetch_verified "$url" "$dest" "$ACM_SHA256" "ダウンロードした a-c-m" ||
  die "取得または checksum 検証に失敗しました（URL・ネットワーク・ACM_* を確認）。vendor/ は更新していません。"
chmod +x "$dest" 2>/dev/null || true
log "配置しました: $dest"

# LICENSE（MIT）も同梱する（失敗しても本体は有効 — best-effort）。
if [ ! -f "$vendor_dir/LICENSE" ]; then
  if fetch_verified "${ACM_BASE_URL}/LICENSE" "$vendor_dir/LICENSE" "$LICENSE_SHA256" "LICENSE"; then
    log "配置しました: $vendor_dir/LICENSE"
  else
    warn "LICENSE の取得に失敗しました（本体は取得済み。必要なら手動で配置してください）。"
  fi
fi
log "agent-context ラッパーが上方探索でこの vendor/ を解決します。"
