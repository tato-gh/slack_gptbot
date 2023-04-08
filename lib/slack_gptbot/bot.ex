defmodule SlackGptbot.Bot do
  use GenServer
  alias SlackGptbot.API.{ChatGPT, Slack}

  # メンションなしでbotが動くチャンネル印
  @bot_passive_channels ~w(bot- botto-)

  # botから会話をスタートする対象チャンネル印
  @bot_active_channels ~w(botto-)
  @default_post_schedule "0 22 * * *"

  @doc """
  開始処理
  """
  def start_link(name, conversion, messages \\ []) do
    {channel, ts} = conversion
    GenServer.start_link(__MODULE__, %{channel: channel, ts: ts, messages: messages}, name: name)
  end

  @impl GenServer
  def init(args) do
    state = Map.take(args, [:channel, :ts, :messages])
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:first_post, message}, state) do
    # stream未対応のため先にリアクションで応答
    Slack.send_reaction(state.channel, "robot_face", state.ts)
    # 本対応
    {messages, reply} = get_message_from_chatgpt(state.channel, message)
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

  def get_message_from_chatgpt(channel, message) do
    channel_prompt = fetch_channel_prompt(channel)
    messages = ChatGPT.get_first_messages(message, channel_prompt)
    reply = ChatGPT.get_message(messages)

    {messages, reply}
  end

  def direct_handlable_channel?(channel) do
    channel_name= channel |> Slack.get_channel_name()

    @bot_passive_channels
    |> Enum.find(& String.starts_with?(channel_name, &1))
    |> (if do: true, else: false)
  end

  def first_postable_channel?(channel_name) do
    @bot_active_channels
    |> Enum.find(& String.starts_with?(channel_name, &1))
    |> (if do: true, else: false)
  end

  defp fetch_channel_prompt(channel) do
    purpose = Slack.get_channel_purpose(channel)

    ~r{prompt:(?<prompt>.+?(\n\n|\z))}s
    |> Regex.named_captures(purpose || "")
    |> Kernel.||(%{})
    |> Map.get("prompt")
  end

  def fetch_post_schedule(purpose) do
    ~r{schedule:(?<schedule>.+?$)}m
    |> Regex.named_captures(purpose)
    |> Kernel.||(%{})
    |> Map.get("schedule", @default_post_schedule)
    |> String.trim()
  end
end
