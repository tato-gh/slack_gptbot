# SlackGptbot

ChatGPT bot for Slack Application (my practice to use chatgpt api).

- [x] Slack上でChatGPTの応答をみれること
- [x] スレッド内で同一会話を継続すること
- [x] チャンネル説明をプロンプトとして使えること
- [x] チャンネルによっては定期的にBotから会話がとばせること


## Environment

- BD_SCHEMA: Bandit schema. http or https
- BD_HOST: Bandit host
- BD_PORT: Bandit port
- SLACK_SIGNING_SECRET: Slack Signing Secret
- SLACK_BOT_TOKEN: Slack Bot Token
- CHATGPT_TOKEN: ChatGPT Access Token


## Get it up for now

```
cp .env.sample .env
docker run -it -p 80:80 -v `pwd`:/srv --env-file .env elixir:1.14 /bin/bash

# in container
cd /srv
mix deps.get
iex -S mix run
```


## Slack api permissions

- app_mentions:read
- channels:history
- channels:raad
- chat:write
- im:history
- im:write
- reactions:write

