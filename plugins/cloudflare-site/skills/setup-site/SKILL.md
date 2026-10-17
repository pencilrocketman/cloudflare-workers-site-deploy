---
name: setup-site
description: private な GitHub リポジトリの静的ファイルを、cloudflare-workers-site-deploy で Cloudflare Access 付きの Worker としてデプロイできるようにセットアップする。「このサイトを Cloudflare にデプロイできるようにして」「新しいサイトのリポジトリを作りたい」「wrangler の設定をこのフレームワークに移行して」と言われたときに使う。
---

# サイトリポジトリのセットアップ

対象はカレントディレクトリのリポジトリ。作業の前に、以下の前提を順に確認する。

## 1. 前提の確認

- `gh repo view --json visibility,nameWithOwner` で visibility が `PRIVATE` であることを確認する。
  public なら作業を止め、private にするよう伝える（action も public からのデプロイを拒否する）。
- 利用者がアカウント単位の初回準備（README の「初回準備」）を済ませているか確認する。
  未完了なら README の手順を案内し、済むまで先に進まない。
  - R2 バケット（Terraform state 用）
  - R2 API トークン（そのバケットへの Object Read & Write）
  - Cloudflare の **ユーザー** API トークン。権限は Workers Scripts: Edit、Access: Apps and Policies: Edit、User Details: Read

## 2. 利用者に聞くこと

- デプロイするディレクトリ（`assets_dir`、デフォルト `public`）。リポジトリ直下を配信する場合は `.` とし、
  `.github` などを配信しないように `.assetsignore` を置く。
- Worker 名。デフォルトはリポジトリ名で、URL は `https://<worker名>.<workers.devサブドメイン>.workers.dev` になる。
- トークン所有者以外に閲覧を許可するメールアドレス（任意）。

## 3. workflow の配置

`templates/deploy.yml` を `.github/workflows/deploy.yml` にコピーし、`assets_dir` を合わせる。
Worker 名をリポジトリ名から変える場合は `worker_name:` を追加する。
ビルドが必要なサイトなら、checkout と action の間にビルドステップを入れる。

既存の `wrangler.jsonc` / `wrangler.toml` や、`cloudflare/wrangler-action` を使う workflow があれば、
action が wrangler 設定を毎回生成するので不要になる。利用者に確認してから削除する。

## 4. secrets と variables の登録

secret の値は Claude が扱わない。利用者自身にプロンプトで次を実行してもらう（`gh` が値の入力を求める）。

```
! gh secret set CLOUDFLARE_API_TOKEN
! gh secret set R2_ACCESS_KEY_ID
! gh secret set R2_SECRET_ACCESS_KEY
```

variables は秘密ではないので、値を聞いて Claude が登録してよい。

```
gh variable set CLOUDFLARE_ACCOUNT_ID --body <アカウントID>
gh variable set TF_STATE_BUCKET --body <バケット名>
gh variable set ALLOWED_EMAILS --body $'a@example.com\nb@example.com'   # 任意
```

## 5. 既存の Access アプリの確認

同じホスト名に手作業で作った Access アプリがあると、Terraform が別のアプリを作って二重管理になる。
利用者に Cloudflare ダッシュボード（Zero Trust → Access → Applications）で確認してもらい、
あれば README の「既存の Access アプリを引き継ぐ」の手順で import してから初回デプロイする。

## 6. 初回デプロイ

コミットと push（または `gh workflow run deploy.yml`）を利用者に確認してから行い、
`gh run watch` で結果を見る。成功したら URL を開き、Access のログイン画面が出ることを確認してもらう。
