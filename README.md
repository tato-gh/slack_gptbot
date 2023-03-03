# SlackGptbot

ChatGPT bot for Slack Application (my practice to use chatgpt api).


## Environment

BD_SCHEMA: Bandit schema. http or https
BD_HOST: Bandit host
BD_PORT: Bandit port
SLACK_SIGNING_SECRET: Slack Signing Secret
SLACK_BOT_TOKEN: Slack Bot Token
CHATGPT_TOKEN: ChatGPT Access Token


## Slack上での使い方

- アプリをチャンネルに追加
- アプリに対してメンションをつけると会話がスタートする
  - メンションと一緒に書いた文章は初期設定（システム情報）として使われる
    - 例１： `@bot 英訳してください`
    - 例２： `@bot 日本のアニメキャラになりきってください`
  - 同じ会話を続けるにはスレッドを使う
- システムが落ちない限りは、90日を超えないと会話情報は消えない
  - データ量が多くなるとサーバに蓄積されるので注意する
  - この辺りの仕様は、個人利用のため何も検証していない

