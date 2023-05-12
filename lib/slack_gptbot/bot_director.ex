defmodule SlackGptbot.BotDirector do
  @moduledoc """
  Botのプロセスを管理するサーバ
  """

  use GenServer

  # データ掃除実施の頻度。指定値に一回程度
  @cleaning_frequency 100
  @limit_num_conversations 1000
  @limit_num_dates 90

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    {:ok, []}
  end

  @impl GenServer
  def handle_cast({:mention, {conversation, message}}, state) do
    bot_name = make_name(conversation)
    if Process.whereis(bot_name) do
      {:noreply, state}
    else
      {:ok, _} = SlackGptbot.Bot.start_link(bot_name, conversation)
      GenServer.cast(bot_name, {:first_post, message})
      {:noreply, register_bot(state, bot_name)}
    end
  end

  def handle_cast({:im_first_post, {conversation, message}}, state) do
    bot_name = make_name(conversation)
    {:ok, _} = SlackGptbot.Bot.start_link(bot_name, conversation)
    GenServer.cast(bot_name, {:first_post, message})
    {:noreply, register_bot(state, bot_name)}
  end

  def handle_cast({:channel_first_post, {conversation, message}}, state) do
    {channel, _} = conversation
    if SlackGptbot.Bot.direct_handlable_channel?(channel) do
      bot_name = make_name(conversation)
      {:ok, _} = SlackGptbot.Bot.start_link(bot_name, conversation)
      GenServer.cast(bot_name, {:first_post, message})
      state = if :rand.uniform(@cleaning_frequency) == 1, do: remove_expired_bot(state), else: state
      {:noreply, register_bot(state, bot_name)}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:thread_post, {conversation, message}}, state) do
    bot_name = make_name(conversation)
    if Process.whereis(bot_name) do
      GenServer.cast(bot_name, {:thread_post, message})
    end
    {:noreply, state}
  end

  def handle_cast({:bot_maybe_myself, _}, state) do
    # 現状botメッセージは完全に無視する
    {:noreply, state}
  end

  def handle_cast({:unknown, _}, state) do
    {:noreply, state}
  end

  def handle_cast({:own_first_post, channel}, state) do
    # botから送るためのメッセージを取得
    {messages, reply} = SlackGptbot.Bot.get_first_reply_from_chatgpt(channel, "どうぞ", %{model: "gpt-4"})
    # slackの動的に送り会話識別子(ts)を入手
    ts = SlackGptbot.API.Slack.send_message(reply, channel, nil)

    conversation = {channel, ts}
    bot_name = make_name(conversation)
    {:ok, _} = SlackGptbot.Bot.start_link(bot_name, conversation, messages)

    {:noreply, state}
  end

  defp register_bot(bot_list, bot_name) do
    [{bot_name, DateTime.now!("Etc/UTC")}] ++ bot_list
  end

  defp remove_expired_bot(bot_list) do
    current_time = DateTime.now!("Etc/UTC")

    bot_list_keep =
      bot_list
      |> Enum.slice(0, @limit_num_conversations)
      |> Enum.take_while(fn {_bot_name, created_at} ->
        num_dates =
          DateTime.diff(current_time, created_at)
          |> Kernel./(60 * 60 * 24)
        num_dates <= @limit_num_dates
      end)
    ind_kept = length(bot_list_keep)

    # 掃除対象プロセス停止
    bot_list
    |> Enum.slice(ind_kept..-1)
    |> Enum.each(fn {bot_name, _} ->
      Process.whereis(bot_name)
      |> Process.exit(:kill)
    end)

    bot_list
  end

  defp make_name(conversation) do
    {channel, ts} = conversation
    :"#{channel}_#{ts}"
  end
end
