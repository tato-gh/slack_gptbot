import Config

config :slack_gptbot, SlackGptbot.Scheduler,
  debug_logging: false,
  jobs: [
    # Every hour
    {"0 * * * *",  {SlackGptbot.PostScheduler, :crawl_channels_info, []}},
  ]
