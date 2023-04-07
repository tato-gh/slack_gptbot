defmodule SlackGptbot.ActiveBot do
  use GenServer

  alias SlackGptbot.API.Slack

  # botが動くチャンネル印
  @bot_channel "botto-"
  @polling_interval_msec 3600 * 1000
  @default_send_interval_hours 24 * 7

  def start_link([]) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    Process.send_after(self(), :run_all, 1000)
    {:ok, %{"channels" => %{}}}
  end

  @impl GenServer
  def handle_info(:run_all, state) do
    channels = merge_latest_channels(state["channels"])

    # 未送信チャンネルに対して送信予約
    Process.send_after(self(), :send_first_time, 1000)

    # 同処理の定期実行予約
    Process.send_after(self(), :run_all, @polling_interval_msec)
#
    {:noreply, %{"channels" => channels}}
  end

  @impl GenServer
  def handle_info(:send_first_time, state) do
    sent_ids = send_first_time(state["channels"])
    start_at = NaiveDateTime.utc_now()
    state =
      Map.update!(state, "channels", fn acc ->
        Enum.reduce(sent_ids, acc, fn id, inner ->
          Map.update!(inner, id, & Map.put(&1, :start_at, start_at))
        end)
      end)

    # 次回予約
    sent_ids
    |> Enum.each(fn id ->
      interval_hour = get_in(state, ["channels", id, :interval])
      Process.send_after(self(), {:send, id}, interval_hour * 3600 * 1000)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:send, channel_id}, state) do
    send_message(channel_id)
    interval_hour = get_in(state, [channel_id, :interval])
    Process.send_after(self(), {:send, channel_id}, interval_hour * 3600 * 1000)

    {:noreply, state}
  end

  defp send_first_time(channels) do
    channels
    |> Map.values()
    |> Enum.reject(& Map.get(&1, :start_at))
    |> Enum.map(fn channel ->
      send_message(channel.id)
      channel.id
    end)
  end

  defp send_message(channel_id) do
    # 簡易的に、情報を偽造してBotのイベントを起こしている
    params = %{
      "event" => %{
        "channel" => channel_id,
        "ts" => nil,
        "text" => "どうぞ",
        "type" => "app_mention"
      }
    }
    GenServer.cast(SlackGptbot.Bot, {:message, params})
  end

  defp merge_latest_channels(channels) do
    Slack.get_channels()
    |> Enum.filter(& Map.get(&1, "name") |> String.starts_with?(@bot_channel))
    |> Map.new(fn info ->
      interval = fetch_send_intervel(get_in(info, ["purpose", "value"]))
      key = info["id"]
      value =
        Map.get(channels, key, %{})
        |> Map.merge(%{id: info["id"], name: info["name"], interval: interval})
      {key, value}
    end)
  end

  defp fetch_send_intervel(purpose) do
    ~r{schedule:(?<schedule>.+?\Z)}s
    |> Regex.named_captures(purpose)
    |> Kernel.||(%{})
    |> Map.get("schedule", "#{@default_send_interval_hours}")
    |> then(fn value_s ->
      try do
        String.to_float(value_s)
      rescue
        _ -> @default_send_interval_hours
      end
    end)
  end
end
