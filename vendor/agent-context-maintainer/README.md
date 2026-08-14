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
checksum 検証してから配置する。座標を環境変数で上書きする場合は `ACM_SHA256` の併記が必要。

統合上の確定事項（テンプレート側に反映済み）:

- テンプレート同梱の手書き文脈ファイル（`.agents/core.md` 等）はマーカーを持たないため、
  bootstrap は `agent-context scaffold . --agent auto --append-generated-block` で
  「手書き内容を保全しつつ管理ブロックを追記」する。素の `scaffold` はマーカー不在で拒否する。
- scaffold は `.agents/profiles/*.md`・`.agents/provider-registry.yaml`・`.gemini/settings.json`
  を生成し、以後の `agent-context check` が green になる。
- a-c-m は `.agents/` 断片を AGENTS.md へ**インライン展開しない**。ツール一覧
  （`scripts/gen-tool-list.py` → `.agents/tools.md`）は AGENTS.md の手書き領域から
  **参照（ポインタ）**で導線を張り、乖離検査は `just gen-tools-check` が担う。

## 取得方法

このリポジトリ直下で取得スクリプトを実行します（**ネットワークが必要**・best-effort）:

```sh
bash scripts/vendor-acm.sh
```

取得元は環境変数で上書きできます:

```sh
ACM_REF=v0.2.0 bash scripts/vendor-acm.sh
ACM_REPO=owner/repo ACM_FILE=scripts/tool.py bash scripts/vendor-acm.sh
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
