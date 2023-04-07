import Config

config :slack_gptbot, SlackGptbot.Scheduler,
  debug_logging: false,
  jobs: [
    # Every minute
    {"* */6 * * *",  {SlackGptbot.PostScheduler, :crawl_channels_info, []}},
  ]
