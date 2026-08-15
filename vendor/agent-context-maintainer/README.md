# vendor/agent-context-maintainer

このディレクトリは **agent-context-maintainer（a-c-m）の vendored copy** を置く場所です。

## 位置づけ

- a-c-m は「単一ファイル」構成のツールであり、flake input として取り込むより
  **vendored copy + 更新チェック CI** の方が摩擦が少ない。
- 実体は `agent_context.py`（依存フリー・Python 3.9+）で、このディレクトリに
  `LICENSE`（MIT）とともに **git 管理下でコミットする**
  （`.gitignore` しない。再現性のため取得済みのバージョンを固定する）。
- devShell が提供する配置非依存ラッパー `agent-context`（`wrappers/agent-context.sh`）が、
  実行時に PWD から上方探索してこの `vendor/agent-context-maintainer/` を見つけ、
  `scaffold` / `check` / `skills check` 等を委譲する。
  shellHook・CI・ドキュメントはすべてラッパー `agent-context` を参照し、実体の配置に依存しない。

## 確定済みの取得座標（v0.1.1 で照合済み）

| 項目 | 値 |
|---|---|
| リポジトリ | `ponponusa/agent-context-maintainer` |
| ref（既定） | commit SHA `25354c94db194f9c09bfaa3108542e9674325c7b`（= v0.1.1。**可変タグではなく SHA 固定**） |
| 単一ファイル | `scripts/agent_context.py` → 配置名 `agent_context.py`（sha256 を vendor-acm.sh に固定） |
| 生成マーカー | `<!-- agent-context-maintainer:begin -->` / `<!-- agent-context-maintainer:end -->` |
| サブコマンド | `providers` / `skills` / `inventory` / `check` / `scaffold`（`sync` は存在しない） |

**検証セマンティクス（CI ゲート）:** `vendor-acm.sh` は既存の vendored copy を**上書きしない**。
存在すれば固定 sha256 と照合し、一致なら成功（取得スキップ）・**不一致ならエラー終了**する
（改変・破損をダウンロードで隠蔽せず CI 失敗として表面化させる）。取得時もダウンロード物を
checksum 検証してから配置する。座標を環境変数で上書きする場合は `ACM_SHA256` の併記が
**必須**（未指定は即エラー——検証なしで旧 vendor を「一致」と誤報する経路を残さない。
`LICENSE_SHA256` のみ任意・best-effort）。

統合上の確定事項（テンプレート側に反映済み）:

- テンプレート同梱の手書き文脈ファイル（`.agents/core.md` 等）はマーカーを持たないため、
  bootstrap は `agent-context scaffold . --agent generic --append-generated-block` で
  「手書き内容を保全しつつ管理ブロックを追記」する。素の `scaffold` はマーカー不在で拒否する。
  `--agent generic` 固定・git init 後の 2 回実行（Repository Snapshot の固定点収束）とする——
  `--agent auto` は実行者の環境変数で profiles の active フラグが変わり、CI の生成一致ゲートと
  食い違うため使わない。
- scaffold は `.agents/profiles/*.md`・`.agents/provider-registry.yaml`・`.gemini/settings.json`
  を生成し、以後の `agent-context check` が green になる。
- `check` は**構造検査**（必須ファイルの存在・相互参照・マーカー整合）であり、生成結果の
  一致は検査しない。ドリフト検出は CI の**生成一致ゲート**（決定的 scaffold +
  `git diff --exit-code`）が担う。
- a-c-m は `.agents/` 断片を AGENTS.md へ**インライン展開しない**。ツール一覧
  （`scripts/gen-tool-list.py` → `.agents/tools.md`）は AGENTS.md の手書き領域から
  **参照（ポインタ）**で導線を張り、乖離検査は `just gen-tools-check` が担う。

## 取得方法

このリポジトリ直下で取得スクリプトを実行します（**ネットワークが必要**・best-effort）:

```sh
bash scripts/vendor-acm.sh
```

意図的な更新（版の差し替え）は、**旧 vendor の削除 → 新座標＋checksum の明示 → 既定座標の
恒久更新**の 3 手順で行います。座標を上書きする場合 `ACM_SHA256` は必須です（未指定はエラー。
既存 vendor があるとスクリプトは上書きしないため、削除してから実行します）:

```sh
# 1) 旧 vendor を削除（スクリプトは既存を上書きしない）
rm -f vendor/agent-context-maintainer/agent_context.py
# 2) 新しい commit SHA と、その内容の sha256 を明示して取得
ACM_REF=<commit-sha> ACM_SHA256=<新ファイルの sha256> bash scripts/vendor-acm.sh
# 3) scripts/vendor-acm.sh の DEFAULT_ACM_REF / DEFAULT_ACM_SHA256 を新しい値へ更新してコミット
#    （テンプレート同梱の templates/*/scripts/vendor-acm.sh も同期する）
```

生成プロジェクト（`nix flake init -t` で展開したリポジトリ）では bootstrap.sh が
vendor 不在時に同スクリプトを自動実行します（a-c-m は単一ファイルのため、
プロジェクトごとの vendoring は設計上許容される摩擦です）。

## dev override

vendoring せずローカルの a-c-m チェックアウトを使う場合は `SUBACO_ACM_DEV` を設定します
（チェックアウトのディレクトリ・実行ファイル・`.py` 単一ファイルのいずれか可 —
`wrappers/agent-context.sh`）:

```sh
export SUBACO_ACM_DEV=/path/to/agent-context-maintainer
```
