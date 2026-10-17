---
name: manage-access
description: cloudflare-workers-site-deploy でデプロイしているサイトの閲覧許可メールアドレスを確認・追加・削除する。「〇〇さんも見られるようにして」「許可されている人を確認して」「〇〇さんのアクセスを外して」と言われたときに使う。
---

# 閲覧許可メールの管理

対象はカレントディレクトリのサイトリポジトリ。許可メールは GitHub Actions の variable
`ALLOWED_EMAILS`（改行区切り）に入っていて、デプロイ時に Cloudflare Access へ反映される。
API トークンの所有者は、この一覧に関係なく常に閲覧できる。

## 確認

```
gh variable get ALLOWED_EMAILS
```

未設定ならトークン所有者だけが閲覧できる状態。

## 変更

1. 現在の一覧を取得し、追加・削除した後の一覧を利用者に見せて確認を取る。
2. `gh variable set ALLOWED_EMAILS --body "<改行区切りの一覧>"` で更新する。全員を外す場合は
   `gh variable delete ALLOWED_EMAILS`。
3. variable の変更だけでは Access に反映されない。`gh workflow run deploy.yml` でデプロイを
   実行し、`gh run watch` で成功を確認する。
