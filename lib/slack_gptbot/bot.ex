defmodule SlackGptbot.Bot do
  use GenServer
  alias SlackGptbot.API.{ChatGPT, Slack}

  # メンションなしでbotが動くチャンネル印
  @bot_channel "bot-"

  def start_link(name, conversion) do
    {channel, ts} = conversion
    GenServer.start_link(__MODULE__, %{channel: channel, ts: ts}, name: name)
  end

  @impl GenServer
  def init(args) do
    state = Map.take(args, [:channel, :ts])
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:first_post, message}, state) do
    # stream未対応のため先にリアクションで応答
    Slack.send_reaction(state.channel, "robot_face", state.ts)
    # 本対応
    channel_prompt = fetch_channel_prompt(state.channel)
    messages = ChatGPT.get_first_messages(message, channel_prompt)
    reply = ChatGPT.get_message(messages)
    Slack.send_message(reply, state.channel, state.ts)

    {:noreply, state |> Map.put(:messages, messages)}
  end

  def handle_cast({:thread_post, message}, state) do
    ChatGPT.add_user_message(state.messages, message)
    |> case do
      {:ok, messages} ->
        reply = ChatGPT.get_message(messages)
        Slack.send_message(reply, state.channel, state.ts)
        messages = ChatGPT.add_assistant_message(messages, reply)
        {:noreply, state |> Map.put(:messages, messages)}
      {:nothing, messages} ->
        {:noreply, state |> Map.put(:messages, messages)}
    end
  end

  def direct_handlable_channel?(channel) do
    channel
    |> Slack.get_channel_name()
    |> String.starts_with?(@bot_channel)
  end

  defp fetch_channel_prompt(channel) do
    purpose = Slack.get_channel_purpose(channel)

    ~r{prompt:(?<prompt>.+?(\n\n|\z))}s
    |> Regex.named_captures(purpose || "")
    |> Kernel.||(%{})
    |> Map.get("prompt")
  end
end
