# subaco タスクランナー（just 規約: fmt / lint / check）。
# subaco 自身の devShell（flake.nix の devShells.default）に nixfmt / statix / nil /
# shellcheck / shfmt / just が入る。`nix develop`（または direnv allow）で入って実行する。

# 対象ファイルの列挙（Nix / シェル / Python）。
nix_files := "flake.nix templates/minimal/flake.nix templates/standard/flake.nix templates/multi-agent/flake.nix templates/standard/agent-tools.nix templates/multi-agent/agent-tools.nix"

# 既定: レシピ一覧
default:
    @just --list

# Nix / シェルの整形（破壊的。nixfmt-rfc-style + shfmt）。
fmt:
    nixfmt {{ nix_files }}
    # シェルは 2 スペース・ケースインデント（.editorconfig と一致）。
    shfmt -w -i 2 -ci $(find . -name '*.sh' -not -path './vendor/*')

# Nix / シェルの整形チェック（非破壊。CI 用）。
fmt-check:
    nixfmt --check {{ nix_files }}
    shfmt -d -i 2 -ci $(find . -name '*.sh' -not -path './vendor/*')

# lint（statix = Nix lint、shellcheck = シェル lint）。
# wrappers/*.sh は writeShellApplication に readFile される断片で shebang を持たないため
# `-s bash` を明示する。shebang 付きの独立スクリプト（bootstrap / hooks / scripts）は自動判定。
lint:
    statix check .
    shellcheck $(find . -name '*.sh' -not -path './vendor/*' -not -path '*/wrappers/*')
    shellcheck -s bash templates/*/wrappers/*.sh

# 構文チェックのみ（依存取得・ビルドなし・オフラインで完結）。
# 全 .nix を nix-instantiate --parse、全 .py を py_compile で検査する。
check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "▶ nix parse"
    for f in {{ nix_files }}; do
      nix-instantiate --parse "$f" >/dev/null && echo "  ok: $f"
    done
    echo "▶ python py_compile"
    python3 -m py_compile \
      scripts/gen-tool-list.py \
      templates/standard/scripts/gen-tool-list.py \
      templates/multi-agent/scripts/gen-tool-list.py \
      templates/multi-agent/scripts/sandbox_run.py \
      templates/multi-agent/lib/hive_team.py
    echo "  ok: python"

# 「## 利用可能ツール」フラグメント（.agents/tools.md）を agent-tools.nix から再生成する。
gen-tools:
    python3 scripts/gen-tool-list.py --tools-nix templates/standard/agent-tools.nix --out templates/standard/.agents/tools.md
    python3 scripts/gen-tool-list.py --tools-nix templates/multi-agent/agent-tools.nix --out templates/multi-agent/.agents/tools.md

# フラグメントが agent-tools.nix と同期しているか検査する（非破壊。CI 用）。
gen-tools-check:
    python3 scripts/gen-tool-list.py --tools-nix templates/standard/agent-tools.nix --out templates/standard/.agents/tools.md --check
    python3 scripts/gen-tool-list.py --tools-nix templates/multi-agent/agent-tools.nix --out templates/multi-agent/.agents/tools.md --check

# sandbox_run.py をシムリポジトリから同期する（正典はテンプレート側・開発とテストは shim 側）。
# 変更手順: subaco-shim 側で編集し just test を green にしてから本レシピで同期・コミットする。
# 両コピーは byte 一致（バナーも共通文面）。sha256 を表示するので一致を目視確認する。
sync-sandbox-run shim_dir="../subaco-shim":
    cp {{ shim_dir }}/scripts/sandbox_run.py templates/multi-agent/scripts/sandbox_run.py
    shasum -a 256 {{ shim_dir }}/scripts/sandbox_run.py templates/multi-agent/scripts/sandbox_run.py

# sandbox_run.py の同期検査（非破壊。隣接 checkout があるときの開発補助）。
sync-sandbox-run-check shim_dir="../subaco-shim":
    diff -q {{ shim_dir }}/scripts/sandbox_run.py templates/multi-agent/scripts/sandbox_run.py
