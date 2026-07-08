"""hive-team: チーム名導出の単一ソース。

正規化規則（**唯一実装**。subaco-hive / subaco-shim は再実装禁止）:
    NFC 正規化 → 小文字化 → ``[a-z0-9_-]`` 以外を ``-`` へ置換 → 64 文字上限。
    （macOS の NFD ファイル名との照合差異を吸収するため NFC 正規化を明記する。）

既定入力: git リポジトリルート（無ければ CWD）のディレクトリ名。
挙動:
  * ``.hive/team`` が不在なら、上記規則で導出して 0600 で書き、正規化名を stdout に出す。
  * 既存時は再導出せず、その内容をそのまま出力する
    （ディレクトリ改名による導出値変化・join 拒否を防ぐ）。

このファイルは devShell の ``hive-team`` ラッパー（writeShellApplication）から
``python3 <このファイル>`` として exec される。subaco_hive は本ロジックを持たず、
``HIVE_TEAM`` 環境変数か ``.hive/team`` を読むだけ。
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import unicodedata

# 正規化後に [a-z0-9_-] 以外を捕捉する。
_INVALID = re.compile(r"[^a-z0-9_-]")

# 空入力・全不可文字などで結果が空になった場合のフォールバック名。
_FALLBACK = "team"


def normalize_team(name: str) -> str:
    """チーム名を正規化する（唯一実装）。"""
    s = unicodedata.normalize("NFC", name)
    s = s.lower()
    s = _INVALID.sub("-", s)
    return s[:64]


def project_root(start: str | None = None) -> str:
    """git リポジトリルートを返す。git 外／git 不在なら ``start``（既定 CWD）を返す。"""
    start = start or os.getcwd()
    try:
        proc = subprocess.run(
            ["git", "-C", start, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError, OSError):
        return start
    root = proc.stdout.strip()
    return root or start


def resolve_team(root: str) -> str:
    """``.hive/team`` を解決する。不在なら導出して 0600 で永続化する。"""
    hive_dir = os.path.join(root, ".hive")
    team_file = os.path.join(hive_dir, "team")

    # 既存時は再導出しない（単一ソースの冪等性）。
    if os.path.isfile(team_file):
        with open(team_file, encoding="utf-8") as f:
            existing = f.read().strip()
        if existing:
            return existing

    # 導出: ルートのディレクトリ名を正規化する。
    base = os.path.basename(os.path.normpath(root))
    team = normalize_team(base) or _FALLBACK

    # .hive は 0700（不在時のみ防御的に作成。初期化の主責務は .envrc / bootstrap）。
    os.makedirs(hive_dir, mode=0o700, exist_ok=True)
    # 0600 で書き込む（O_CREAT 時のモード指定 + 明示 chmod で umask の影響を排除）。
    fd = os.open(team_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        os.write(fd, (team + "\n").encode("utf-8"))
    finally:
        os.close(fd)
    os.chmod(team_file, 0o600)
    return team


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    # 任意: 第1引数でルートを上書きできる（テスト・特殊配置用）。既定は git ルート／CWD。
    root = project_root(args[0] if args else None)
    print(resolve_team(root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
