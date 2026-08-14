#!/usr/bin/env python3
"""gen-tool-list — agent-tools.nix から「## 利用可能ツール」セクションを生成する。

単一情報源 ``agent-tools.nix``（devShell の packages と AGENTS.md 生成の双方が参照する
Nix リスト）を読み、各ツールの用途一行と推奨慣行を付した Markdown セクションを生成する。
これにより flake（実際に入るツール）とエージェント指示（AGENTS.md）の乖離が構造的に起きない。

**重要（a-c-m を AGENTS.md の唯一の書き手として維持する）:**
  本スクリプトは **AGENTS.md を直接編集しない**。出力先は ``.agents/tools.md`` で確定
  （a-c-m v0.1.1 と照合済み——a-c-m は断片を AGENTS.md へインライン展開しないため、
  AGENTS.md 側は手書き領域からの**参照（ポインタ）**のみを持ち、一覧の正本は本出力とする。
  乖離検査は CI の ``--check``（``just gen-tools-check``）が担う）。

パース方針:
  Nix を評価せず、テキストとして ``tier1`` / ``tier2`` の ``[ ... ]`` ブロックから
  ``toolname # 用途コメント`` を正規表現で抽出する（stdlib のみ・オフライン・依存なしで動く）。

使い方:
  gen-tool-list.py [--tools-nix PATH] [--out PATH] [--stdout] [--check]
    --tools-nix  agent-tools.nix のパス（既定: ./agent-tools.nix）
    --out        出力先（既定: ./.agents/tools.md）
    --stdout     ファイルに書かず標準出力へ出す
    --check      既存の --out と生成結果が一致するか検査（差分あれば exit 1・非破壊。CI 用）
"""

from __future__ import annotations

import argparse
import os
import re
import sys

# --- Nix パッケージ名 → 実際にシェルで叩くコマンド名（人間/エージェントが使う名） ---
# agent-tools.nix はパッケージ名（ripgrep 等）で書くが、AGENTS.md では実コマンド名（rg 等）を示す。
_CMD: dict[str, str] = {
    "ripgrep": "rg",
    "yq-go": "yq",
    "gnused": "sed",
    "gawk": "awk",
    "sqlite": "sqlite3",
    "python311": "python3",
    "nixfmt-rfc-style": "nixfmt",
    "coreutils": "coreutils（ls / cat -n 等）",
}

# --- 推奨慣行（第一候補ツールにのみ付す一行注記） ---
_NOTE: dict[str, str] = {
    "ripgrep": "検索は grep でなく rg を第一候補にする。",
    "fd": "ファイル検索は find でなく fd。",
    "sd": "文字列置換は sed でなく sd を第一候補にする（-i の GNU/BSD 差異事故を避ける）。",
    "just": "タスクは just 経由で実行する（just test / just lint）。",
    "ast-grep": "テキスト置換より安全な構文木ベースの検索・書換に用いる。",
    "gh": "PR・Issue 操作は gh（--json 出力で機械可読）。",
}

_TIER_TITLE: dict[str, str] = {
    "tier1": "コアツール（Tier 1・全テンプレート共通）",
    "tier2": "追加ツール（Tier 2・standard 以上）",
}

# `<name> # <comment>` を捕捉する（name はハイフン・ドットを含み得る: yq-go / ast-grep / python311）。
_ENTRY = re.compile(r"^\s*([A-Za-z0-9_.+-]+)\s*(?:#\s*(.*\S))?\s*$")


def _extract_block(text: str, tier: str) -> str:
    """``<tier> = with pkgs; [ ... ];`` の ``[ ... ]`` 内側テキストを返す。"""
    start = text.find(f"{tier} =")
    if start < 0:
        return ""
    open_idx = text.find("[", start)
    close_idx = text.find("]", open_idx)
    if open_idx < 0 or close_idx < 0:
        return ""
    return text[open_idx + 1 : close_idx]


def parse_agent_tools(path: str) -> dict[str, list[tuple[str, str]]]:
    """agent-tools.nix を読み {tier: [(pkg_name, comment), ...]} を返す。"""
    with open(path, encoding="utf-8") as f:
        text = f.read()

    result: dict[str, list[tuple[str, str]]] = {}
    for tier in ("tier1", "tier2"):
        block = _extract_block(text, tier)
        entries: list[tuple[str, str]] = []
        for raw in block.splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            m = _ENTRY.match(line)
            if not m:
                continue
            name = m.group(1)
            comment = (m.group(2) or "").strip()
            entries.append((name, comment))
        result[tier] = entries
    return result


def _line_for(pkg: str, comment: str) -> str:
    """1 ツール分の箇条書き行を生成する（用途一行 + 推奨慣行）。"""
    cmd = _CMD.get(pkg, pkg)
    purpose = comment or pkg
    note = _NOTE.get(pkg)
    body = f"- `{cmd}` — {purpose}"
    if note:
        # 用途が句点で終わらない場合のみ句点を補って推奨慣行と区切る（読みやすさ）。
        sep = "" if purpose.endswith("。") else "。"
        body += f"{sep}{note}"
    return body


def render_section(tools: dict[str, list[tuple[str, str]]]) -> str:
    """「## 利用可能ツール」セクションの Markdown を生成する（決定的出力）。"""
    lines: list[str] = []
    lines.append("## 利用可能ツール")
    lines.append("")
    lines.append(
        "<!-- 生成物: scripts/gen-tool-list.py が agent-tools.nix から生成。"
    )
    lines.append(
        "     手で編集しないでください。ツールの増減は agent-tools.nix で行い本スクリプトを再実行します。 -->"
    )
    lines.append("")
    lines.append(
        "devShell（`direnv allow` で有効化）で以下のツールが利用可能です。"
    )
    lines.append(
        "推奨慣行: 検索は `rg`、ファイル検索は `fd`、置換は `sd`、"
        "タスク実行は `just`（`just test` / `just lint`）を第一候補にしてください。"
    )
    for tier in ("tier1", "tier2"):
        entries = tools.get(tier) or []
        if not entries:
            continue
        lines.append("")
        lines.append(f"### {_TIER_TITLE[tier]}")
        lines.append("")
        for pkg, comment in entries:
            lines.append(_line_for(pkg, comment))
    lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="gen-tool-list.py",
        description="agent-tools.nix から「## 利用可能ツール」セクション（.agents/tools.md）を生成する。",
    )
    parser.add_argument(
        "--tools-nix",
        default="agent-tools.nix",
        help="agent-tools.nix のパス（既定: ./agent-tools.nix）",
    )
    parser.add_argument(
        "--out",
        default=os.path.join(".agents", "tools.md"),
        help="出力先ファイル（既定: ./.agents/tools.md）",
    )
    parser.add_argument("--stdout", action="store_true", help="ファイルに書かず標準出力へ出す")
    parser.add_argument(
        "--check",
        action="store_true",
        help="生成結果と既存 --out の一致を検査（差分で exit 1・非破壊。CI 用）",
    )
    args = parser.parse_args(argv)

    if not os.path.isfile(args.tools_nix):
        print(f"gen-tool-list: agent-tools.nix が見つかりません: {args.tools_nix}", file=sys.stderr)
        return 2

    tools = parse_agent_tools(args.tools_nix)
    if not tools.get("tier1"):
        print(
            f"gen-tool-list: {args.tools_nix} から tier1 を抽出できませんでした（書式を確認）。",
            file=sys.stderr,
        )
        return 2

    section = render_section(tools)

    if args.stdout:
        sys.stdout.write(section)
        return 0

    if args.check:
        # 非破壊の一致検査。CI では agent-context check がマーカー内ドリフトを見るが、
        # 生成物（tools.md）自体の陳腐化はここで検出できる。
        if not os.path.isfile(args.out):
            print(f"gen-tool-list: --check: 出力先が存在しません: {args.out}", file=sys.stderr)
            return 1
        with open(args.out, encoding="utf-8") as f:
            current = f.read()
        if current != section:
            print(
                f"gen-tool-list: --check: {args.out} が agent-tools.nix と不一致です"
                "（gen-tool-list.py を再実行して更新してください）。",
                file=sys.stderr,
            )
            return 1
        return 0

    out_dir = os.path.dirname(args.out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(section)
    print(f"gen-tool-list: 生成しました: {args.out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
