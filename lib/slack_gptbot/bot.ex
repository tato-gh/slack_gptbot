defmodule SlackGptbot.Bot do
  use GenServer

  alias SlackGptbot.API.{ChatGPT, Slack}

  # 話題保持の上限
  @limit_num_conversations 1000
  @limit_num_dates 90

  def start_link([]) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    # TODO: リソースの構造を整理して切り出し検討
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:message, params}, state) do
    # - 開始：自身宛にメンションかつ未作成の話題(ts)。リアクションのみ返す
    # - 蓄積：作成済みの話題かつ自身の発言
    # - 発言：作成済みの話題かつ他者の発言
    # - その他仕様
    #   - データはプロセス保持：GenServerプロセスが消えると話題はすべて消える。
    #   - 話題掃除：開始時、10回に1回程度動く。
    #   - 話題中で使えるメタ発言
    #     - `!` で始まる発言を無視する
    #     - `---` を指定すると一区切りとして、それまでのassistant分を削除する
    #   - 開始時に指定できるメタ設定
    #     - loose/tight ゆれの許容程度
    #
    {channel, ts} = context = fetch_context(params["event"])
    existing_context = if(state[context], do: true, else: false)
    message = fetch_text(params["event"])
    kind = fetch_message_kind(params["event"])

    case {existing_context, kind} do
      {false, :mention} ->
        # 開始
        Slack.send_reaction(channel, "robot_face", ts)
        new_conversation = %{
          "messages" => ChatGPT.init_system_message(message),
          "config" => ChatGPT.build_config(message)
        }
        state = Map.put_new(state, context, new_conversation)
        # 10回に1回程度の頻度でデータを掃除
        state = if :rand.uniform(10) == 1, do: remove_expired_conversation(state), else: state
        {:noreply, state}
      {true, :bot_maybe_myself} ->
        # 自身発言
        messages = ChatGPT.add_assistant_message(get_in(state, [context, "messages"]), message)
        state = put_in(state, [context, "messages"], messages)
        {:noreply, state}
      {true, :someone_post} ->
        # 他者発言
        # - 待ち時間があるので先にリアクションを送る
        current_messages = get_in(state, [context, "messages"])
        config = get_in(state, [context, "config"])
        {reply, messages} = ChatGPT.get_reply_to_user_message(current_messages, message, config)
        if reply do
          Slack.send_message(reply, channel, ts)
        else
          Slack.send_reaction(channel, "eyes", get_in(params, ["event", "ts"]))
        end
        state = put_in(state, [context, "messages"], messages)
        {:noreply, state}
      _ ->
        # Nothing to do
        {:noreply, state}
    end
  end

  defp fetch_context(%{"thread_ts" => ts} = event) do
    %{"channel" => channel} = event

    {channel, ts}
  end

  defp fetch_context(event) do
    %{"channel" => channel, "ts" => ts} = event

    {channel, ts}
  end

  defp fetch_text(event) do
    with text when not is_nil(text) <- event["text"] do
      # メンション除去
      text
      |> String.replace(~r/<@.+?>/m, "", global: true)
      |> String.trim()
    end
  end

  defp fetch_message_kind(%{"type" => "app_mention"}) do
    :mention
  end

  defp fetch_message_kind(%{"bot_id" => _bot_id}) do
    # bot_idはAppIDとは異なる
    # AppIDを参照するならば`get_in(..., ["bot_profile" , "app_id"])`が必要
    # 現状ではbotに反応する必要はないのでbot_idがあれば無視する
    :bot_maybe_myself
  end

  defp fetch_message_kind(_) do
    :someone_post
  end

  defp remove_expired_conversation(state) do
    current_time = DateTime.now!("Etc/UTC")

    state
    |> Enum.sort_by(fn {{_, ts}, _} -> ts end, :desc)
    |> Enum.slice(0, @limit_num_conversations)
    |> Enum.reverse()
    |> Enum.drop_while(fn {{_, ts}, _} ->
      [ts_unix, _] = String.split(ts, ".")
      message_time = DateTime.from_unix!(String.to_integer(ts_unix))
      num_dates =
        DateTime.diff(current_time, message_time)
        |> Kernel./(60 * 60 * 24)
      num_dates >= @limit_num_dates
    end)
    |> Map.new()
  end
end
