defmodule SlackGptbot.Bot do
  use GenServer
  alias SlackGptbot.API.{ChatGPT, Slack}

  # TODO: チャンネルのデータ類を扱うモジュールに分離すること

  # メンションなしでbotが動くチャンネル印
  @bot_passive_channels ~w(bot- botto-)

  # botから会話をスタートする対象チャンネル印
  @bot_active_channels ~w(botto-)
  @default_post_schedule "0 13 * * *"

  @doc """
  開始処理
  """
  def start_link(name, conversion, config \\ %{}, messages \\ []) do
    {channel, ts} = conversion
    GenServer.start_link(__MODULE__, %{channel: channel, ts: ts, messages: messages, config: config}, name: name)
  end

  @impl GenServer
  def init(args) do
    state = Map.take(args, [:channel, :ts, :messages, :config])
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:first_post, {message, image_file}}, state) do
    # stream未対応のため先にリアクションで応答
    Slack.send_reaction(state.channel, "robot_face", state.ts)
    # 本対応
    {messages, reply} = get_first_reply_from_chatgpt(state.channel, message, image_file, state.config)
    Slack.send_message(reply, state.channel, state.ts)
    messages = ChatGPT.add_assistant_message(messages, reply)

    {:noreply, state |> Map.put(:messages, messages)}
  end

  def handle_cast({:thread_post, {message, image_file}}, state) do
    image_url = download_image_if_present(image_file)

    ChatGPT.add_user_message(state.messages, message, image_url)
    |> case do
      {:ok, messages} ->
        reply = ChatGPT.get_message(messages, state.config)
        Slack.send_message(reply, state.channel, state.ts)
        messages = ChatGPT.add_assistant_message(messages, reply)
        {:noreply, state |> Map.put(:messages, messages)}
      {:nothing, messages} ->
        {:noreply, state |> Map.put(:messages, messages)}
    end
  end

  def get_first_reply_from_chatgpt(channel, message, image_file, config) do
    channel_prompt = fetch_channel_prompt(channel)
    {user_prompt, user_message} = parse_first_message(message || "")
    {prompt, prompt_as_message} = merge_prompt(channel_prompt, user_prompt)
    user_message = Enum.join([prompt_as_message, user_message], "\n")

    image_url = download_image_if_present(image_file)

    messages =
      ChatGPT.create_first_messages(prompt, user_message)
      |> update_last_message_with_image(image_url)

    reply = ChatGPT.get_message(messages, config)

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

  defp parse_first_message(message) do
    String.split(message, "\n")
    |> case do
      [row] -> {row, ""}
      [head | tail] -> {head, Enum.join(tail, "\n")}
    end
  end

  defp merge_prompt(channel_prompt, user_prompt) when channel_prompt in ["", nil] do
    {"", user_prompt}
  end

  defp merge_prompt(channel_prompt, user_prompt) do
    words =
      user_prompt
      |> String.trim()
      |> String.split(~r{[[:blank:]　]}u)
      |> Enum.map(&String.trim/1)
      |> Enum.with_index(1)

    channel_prompt = replace_prompt_operation_signs(channel_prompt)

    Enum.reduce(words, {channel_prompt, []}, fn {word, nth}, {prompt, rests} ->
      mark = "$#{nth}"

      prompt
      |> String.contains?(mark)
      |> case do
        false ->
          {prompt, rests ++ [word]}
        true ->
          {String.replace(prompt, "$#{nth}", word), rests}
      end
    end)
    |> then(fn {prompt, rests} ->
      {
        wrap_channel_prompt(prompt),
        Enum.join(rests, " ")
      }
    end)
  end

  defp replace_prompt_operation_signs(prompt) do
    # 各種指示キーを決定する
    # - ${rand:格言,名言,歴史的な発言}
    # - ${order:古代,中世,近代,現代} ただし日単位での切り替え
    # - ${order:1..100/10} ただし日単位での切り替え
    # - ${date:%Y-%m-%d}
    # ユーザー入力をコードに入れている点に注意する
    # 原則データとして扱い実行コードとしては入力を評価しないこと

    prompt
    |> replace_prompt_rand_list()
    |> replace_prompt_order_list()
    |> replace_prompt_order_range()
    |> replace_prompt_date()
  end

  defp replace_prompt_rand_list(prompt) do
    Regex.replace(~r/\${rand:(.+?,.+?)}/, prompt, fn _, hit ->
      String.split(hit, ",")
      |> Enum.random()
    end)
  end

  defp replace_prompt_order_list(prompt) do
    Regex.replace(~r/\${order:(.+?,.+?)}/, prompt, fn _, hit ->
      String.split(hit, ",")
      |> list_fetch_on_date()
    end)
  end

  defp replace_prompt_order_range(prompt) do
    Regex.replace(~r/\${order:(\d+?\.\.\d+?\/\d+?)}/, prompt, fn _, hit ->
      %{"n1" => n1, "n2" => n2, "step" => step} =
        ~r{(?<n1>\d+?)\.\.(?<n2>\d+?)\/(?<step>\d+?)\z}
        |> Regex.named_captures(hit)
        |> Map.new(fn {k, v} -> {k, String.to_integer(v)} end)

      Range.new(n1, n2, step)
      |> Enum.to_list()
      |> list_fetch_on_date()
      |> then(& "#{&1}")
    end)
  end

  defp replace_prompt_date(prompt) do
    Regex.replace(~r/\${date:(.+?)}/, prompt, fn _, hit ->
      today = Date.utc_today()
      try do
        Calendar.strftime(today, hit)
      rescue
        ArgumentError -> ""
      end
    end)
  end

  defp wrap_channel_prompt(prompt) do
    """
    下記の指示に必ず従うこと。
    ### 指示
    #{prompt}
    ###
    """
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

  defp list_fetch_on_date(list) do
    size = length(list)
    {num, _} = Date.day_of_era(Date.utc_today())
    ind = Kernel.rem(num, size)

    Enum.at(list, ind)
  end

  defp download_image_if_present(nil), do: nil

  defp download_image_if_present(image_file) when is_map(image_file) do
    case Slack.download_file(image_file) do
      {:ok, data_uri} -> data_uri
      {:error, _reason} -> nil
    end
  end

  defp update_last_message_with_image(messages, nil), do: messages

  defp update_last_message_with_image(messages, image_url) when is_binary(image_url) do
    case List.pop_at(messages, -1) do
      {nil, _} ->
        messages

      {%{"role" => "user", "content" => text} = last_message, rest} when is_binary(text) ->
        updated_content = [
          %{"type" => "text", "text" => text},
          %{"type" => "image_url", "image_url" => %{"url" => image_url}}
        ]
        rest ++ [%{last_message | "content" => updated_content}]

      _ ->
        messages
    end
  end
end
