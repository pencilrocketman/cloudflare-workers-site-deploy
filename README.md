# cloudflare-workers-site-deploy

private な GitHub リポジトリにある静的ファイル（HTML など）を、Cloudflare Access で保護した
Cloudflare Worker としてデプロイする GitHub Action です。

サイトリポジトリ側で管理するのは **デプロイするファイル** と **閲覧を許可するメールアドレス** だけです。
wrangler の設定や Access の Terraform はこのリポジトリが持ちます。

## 特徴

- **デフォルトで非公開**: 許可メールを何も設定しなければ、API トークンの所有者だけが閲覧できます。
  誰でも見られるサイトにするオプションはありません。
- **保護されていない瞬間を作らない**: Access の設定が成功してから Worker をデプロイします。
- **Access の迂回を防ぐ**: Worker の preview URL（Access の保護対象外）を常に無効にします。
- **private リポジトリからのみ動作**: public リポジトリから実行すると失敗します。

## 仕組み

action は 1 回の実行で次を行います。

1. 実行元リポジトリが private であることを確認
2. Cloudflare API から、API トークン所有者のメールアドレスと、アカウントの workers.dev サブドメインを取得
3. Terraform で Access application と許可ポリシーを作成・更新
   （state は利用者の R2 バケットの `cloudflare-workers-site-deploy/<worker名>.tfstate`）
4. wrangler 設定を生成し、`wrangler deploy` で静的ファイルだけの Worker をデプロイ

サイトの URL は `https://<worker名>.<workers.devサブドメイン>.workers.dev` です。

## 初回準備（Cloudflare アカウントごとに 1 回）

### 1. Terraform state 用の R2 バケットを作る

Cloudflare ダッシュボード → **R2** → **Create bucket**。名前は任意です（例: `tf-state`）。

### 2. R2 API トークンを作る

R2 → **Manage API tokens** → **Create API token**

- Permissions: **Object Read & Write**
- Scope: 手順 1 のバケットだけ
- 表示される **Access Key ID** と **Secret Access Key** を控えます（Secret は一度しか表示されません）

### 3. Cloudflare API トークンを作る

My Profile → **API Tokens** → **Create Token** で、**ユーザーの** API トークンを作ります。
Account API Token は所有者のメールアドレスを持たないため使えません。

必要な権限:

| 種類 | 権限 |
|---|---|
| Account | Workers Scripts: Edit |
| Account | Access: Apps and Policies: Edit |
| User | User Details: Read |

アカウントに workers.dev サブドメインがまだ無ければ、Workers & Pages の画面で作っておきます。

## サイトリポジトリでの使い方

### Claude Code を使う場合

このリポジトリは Claude Code の plugin を提供しています。サイトリポジトリで次を実行し、
「このサイトをデプロイできるようにして」と頼むとセットアップを進められます。

```
/plugin marketplace add pencilrocketman/cloudflare-workers-site-deploy
/plugin install cloudflare-site@cloudflare-workers-site-deploy
```

- `setup-site`: workflow の配置と secrets / variables の登録
- `manage-access`: 閲覧許可メールの確認・追加・削除

### 手動で設定する場合

`.github/workflows/deploy.yml` を作ります。

```yaml
name: Deploy

on:
  push:
    branches:
      - main
  workflow_dispatch: {}

# Terraform state をロックしないので、デプロイを直列化する。
concurrency:
  group: deploy
  cancel-in-progress: false

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # ビルドが必要ならここで行う

      - uses: pencilrocketman/cloudflare-workers-site-deploy@v1
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
          r2_access_key_id: ${{ secrets.R2_ACCESS_KEY_ID }}
          r2_secret_access_key: ${{ secrets.R2_SECRET_ACCESS_KEY }}
          tf_state_bucket: ${{ vars.TF_STATE_BUCKET }}
          allowed_emails: ${{ vars.ALLOWED_EMAILS }}
          assets_dir: public
```

リポジトリの Settings → Secrets and variables → Actions に登録します。

| 種類 | 名前 | 値 |
|---|---|---|
| Secret | `CLOUDFLARE_API_TOKEN` | 初回準備 3 のトークン |
| Secret | `R2_ACCESS_KEY_ID` | 初回準備 2 の Access Key ID |
| Secret | `R2_SECRET_ACCESS_KEY` | 初回準備 2 の Secret Access Key |
| Variable | `CLOUDFLARE_ACCOUNT_ID` | Cloudflare のアカウント ID |
| Variable | `TF_STATE_BUCKET` | 初回準備 1 のバケット名 |
| Variable | `ALLOWED_EMAILS` | 任意。トークン所有者以外に許可するメール（改行区切り） |

`ALLOWED_EMAILS` を変えたら、Access に反映するために workflow を再実行してください
（Actions タブ、または `gh workflow run deploy.yml`）。

### inputs

| 名前 | 必須 | デフォルト | 説明 |
|---|---|---|---|
| `cloudflare_api_token` | ○ | | Cloudflare のユーザー API トークン |
| `cloudflare_account_id` | ○ | | Cloudflare のアカウント ID |
| `r2_access_key_id` | ○ | | R2 の Access Key ID |
| `r2_secret_access_key` | ○ | | R2 の Secret Access Key |
| `tf_state_bucket` | ○ | | Terraform state を置く R2 バケット名 |
| `allowed_emails` | | 空 | 追加で許可するメール（改行またはカンマ区切り）。トークン所有者は常に許可される |
| `worker_name` | | リポジトリ名 | Worker 名。小文字に変換され、英数字とハイフン以外はハイフンになる |
| `assets_dir` | | `public` | デプロイするディレクトリ。リポジトリ直下なら `.` とし、`.assetsignore` で `.github` などを除外する |
| `session_duration` | | `24h` | Access のセッション有効期間 |

### outputs

| 名前 | 説明 |
|---|---|
| `worker_name` | デプロイした Worker 名 |
| `url` | サイトの URL |

## 既存の Access アプリを引き継ぐ

同じホスト名に手作業で作った Access アプリがある場合、そのまま初回デプロイすると Terraform が別のアプリを
作ってしまいます。初回デプロイの前に、このリポジトリを clone して手元で import してください
（Terraform 1.10 以上が必要です）。

```bash
cd terraform

cat > backend.hcl <<EOF
bucket    = "<TF_STATE_BUCKET>"
key       = "cloudflare-workers-site-deploy/<worker名>.tfstate"
endpoints = { s3 = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com" }
EOF

export CLOUDFLARE_API_TOKEN=...       # 初回準備 3
export AWS_ACCESS_KEY_ID=...          # 初回準備 2
export AWS_SECRET_ACCESS_KEY=...      # 初回準備 2

terraform init -backend-config=backend.hcl
terraform import \
  -var account_id=<ACCOUNT_ID> \
  -var worker_name=<worker名> \
  -var domain=<worker名>.<サブドメイン>.workers.dev \
  -var 'allowed_emails=["<あなたのメール>"]' \
  cloudflare_zero_trust_access_application.site <ACCOUNT_ID>/<アプリID>
```

アプリ ID は Zero Trust → Access → Applications でアプリを開いたときの URL に含まれています。
次回のデプロイで、アプリのポリシーはこの action が作るポリシーに置き換わります。
手作業で作った古いポリシーは残るので、不要なら削除してください。

## バージョン

`@v1` のようにメジャーバージョンのタグで参照してください。互換性のない変更はメジャーバージョンを上げて出します。

wrangler は Cloudflare の新しい CLI `cf` に置き換わる予定です。`cf` が stable になったら、
action 内部のデプロイ処理を `cf` に切り替える予定です（サイトリポジトリ側の変更は不要な想定です）。
