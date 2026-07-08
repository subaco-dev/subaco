# vendor/agent-context-maintainer

このディレクトリは **agent-context-maintainer（a-c-m）の vendored copy** を置く場所です。

## 位置づけ

- a-c-m は「単一ファイル」構成のツールであり、flake input として取り込むより
  **vendored copy + 更新チェック CI** の方が摩擦が少ない。
- 実体（単一ファイル）はこのディレクトリ配下に置かれ、**git 管理下でコミットする**
  （`.gitignore` しない。再現性のため取得済みのバージョンを固定する）。
- devShell が提供する配置非依存ラッパー `agent-context`（`wrappers/agent-context.sh`）が、
  実行時に PWD から上方探索してこの `vendor/agent-context-maintainer/` を見つけ、
  `scaffold` / `check` / `sync` / `skills check` を委譲する。
  shellHook・CI・ドキュメントはすべてラッパー `agent-context` を参照し、実体の配置に依存しない。

## 取得方法

このリポジトリ直下で取得スクリプトを実行します（**ネットワークが必要**・best-effort）:

```sh
bash scripts/vendor-acm.sh
```

取得元は環境変数で上書きできます（既定値は暫定 — 下記 TODO）:

```sh
ACM_REF=v1.2.3 bash scripts/vendor-acm.sh
ACM_REPO=owner/repo ACM_FILE=tool.py bash scripts/vendor-acm.sh
```

生成プロジェクト（`nix flake init -t` で展開したリポジトリ）でも同じ
`scripts/vendor-acm.sh` を実行して各プロジェクトの `vendor/` を用意します
（a-c-m は単一ファイルのため、プロジェクトごとの vendoring は設計上許容される摩擦です）。

## dev override

vendoring せずローカルの a-c-m チェックアウトを使う場合は `SUBACO_ACM_DEV` を設定します
（ディレクトリ・実行ファイル・`.py` 単一ファイルのいずれか可 — `wrappers/agent-context.sh`）:

```sh
export SUBACO_ACM_DEV=/path/to/agent-context-maintainer
```

## TODO（段階3で確定）

- a-c-m の実リポジトリ座標（org/repo）・ref・**単一ファイル名**・最終レイアウトを確定し、
  `scripts/vendor-acm.sh` の既定値（`ACM_REPO` / `ACM_REF` / `ACM_FILE`）を実値へ固定する。
- 実体パスが確定したら `wrappers/agent-context.sh` の候補列（`exec_acm`）を実レイアウトへ絞る。
- 生成マーカー（`<!-- agent-context-maintainer:begin -->` / `:end -->`）と
  `.agents/` 断片の取り込みパスを a-c-m 実体と照合する（`scripts/gen-tool-list.py` の出力
  `.agents/tools.md` の取り込み位置を含む）。

> このディレクトリは取得前は README のみです。`scripts/vendor-acm.sh` の実行後に
> a-c-m の単一ファイルが同居します（このマシンはオフライン前提のため未取得）。
