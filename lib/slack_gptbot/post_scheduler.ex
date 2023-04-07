defmodule SlackGptbot.PostScheduler do
  @moduledoc """
  Slackのチャンネル情報をクロールして、Botの投稿日時管理などを行うサーバ
  """

  use GenServer

  @waiting_time_min_sec 3600

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast(:channels_crawling, state) do
    state = merge_latest_channels(state)
    sent_ids = start_conversation(state)
    start_at = NaiveDateTime.utc_now()
    state =
      Enum.reduce(sent_ids, state, fn id, acc ->
        Map.update!(acc, id, & Map.put(&1, :start_at, start_at))
      end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:post_scheduled, channel_id}, state) do
    GenServer.cast(SlackGptbot.BotDirector, {:own_first_post, channel_id})
    reserve_next_post(Map.get(state, channel_id))

    {:noreply, state}
  end

  @doc """
  Slackチャンネルの巡回・設定更新処理
  """
  def crawl_channels_info do
    GenServer.cast(__MODULE__, :channels_crawling)
  end

  defp merge_latest_channels(channels) do
    SlackGptbot.API.Slack.get_channels()
    |> Enum.filter(& Map.get(&1, "name") |> SlackGptbot.Bot.first_postable_channel?())
    |> Map.new(fn info ->
      schedule = SlackGptbot.Bot.fetch_post_schedule(get_in(info, ["purpose", "value"]))
      key = info["id"]
      value =
        Map.get(channels, key, %{})
        |> Map.merge(%{id: info["id"], name: info["name"], schedule: schedule})
      {key, value}
    end)
  end

  defp start_conversation(channels) do
    channels
    |> Map.values()
    |> Enum.reject(& Map.get(&1, :start_at))
    |> Enum.map(fn channel ->
      # 初回投稿
      GenServer.cast(SlackGptbot.BotDirector, {:own_first_post, channel.id})
      # 次回投稿予約
      reserve_next_post(channel)

      channel.id
    end)
  end

  defp reserve_next_post(channel) do
    try do
      next_datetime = next_execution_datetime(channel.schedule)
      waiting_sec =
        Enum.max([
          NaiveDateTime.diff(next_datetime, NaiveDateTime.utc_now()),
          @waiting_time_min_sec
        ])
      Process.send_after(self(), {:post_scheduled, channel.id}, waiting_sec * 1000)
    rescue
      error -> error
    end
  end

  defp next_execution_datetime(cron_expression) do
    # cron形式の式をパース
    {:ok, cron} = Crontab.CronExpression.Parser.parse(cron_expression)

    # 現在時刻から次の実行時刻を計算
    {:ok, next_datetime} = Crontab.Scheduler.get_next_run_date(cron)

    next_datetime
  end
end
