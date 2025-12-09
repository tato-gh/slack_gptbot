import Config

if config_env() == :prod do
  config :slack_gptbot,
    bd_scheme: System.get_env("BD_SCHEME") || "http",
    bd_ip: System.get_env("BD_IP") || "0.0.0.0",
    bd_port: String.to_integer(System.get_env("BD_PORT") || "8080"),
    slack_signing_secret: System.fetch_env!("SLACK_SIGNING_SECRET"),
    slack_bot_token: System.fetch_env!("SLACK_BOT_TOKEN"),
    openai_api_key: System.fetch_env!("OPENAI_API_KEY"),
    server_base_url: System.get_env("SERVER_BASE_URL")
end
