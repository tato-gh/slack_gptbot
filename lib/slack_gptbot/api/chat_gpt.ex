defmodule SlackGptbot.API.ChatGPT do

  def init_system_message(message) do
    # その他、メタ設定が必要であれば追加する
    [%{"role" => "system", "content" => message}]
  end

  def add_assistant_message(messages, message) do
    messages ++ [%{"role" => "assistant", "content" => message}]
  end

  @doc """
  ユーザー発言に対する返信内容とメッセージ群を返す
  """
  def get_reply_to_user_message(messages, message, config)

  def get_reply_to_user_message(messages, "!" <> _rest, _config), do: {nil, messages}

  def get_reply_to_user_message(messages, "コメント" <> _rest, _config), do: {nil, messages}

  def get_reply_to_user_message([system | _rest], "---", _config), do: {nil, [system]}

  def get_reply_to_user_message([system | _rest], "リセット", _config), do: {nil, [system]}

  def get_reply_to_user_message([system | _rest], "---" <> rest, config) do
    new_messages = add_user_message([system], rest)
    reply = get_message(new_messages, config)

    {reply, new_messages}
  end

  def get_reply_to_user_message(messages, message, config) do
    new_messages = add_user_message(messages, message)
    reply = get_message(new_messages, config)

    {reply, new_messages}
  end

  def add_user_message(messages, message) do
    messages ++ [%{"role" => "user", "content" => message}]
  end

  def get_message(messages, config) do
    data = build_post_data(messages, config)

    case req_post(data) do
      {:ok, response} ->
        response.body
        |> Map.get("choices")
        # 設定によって回答候補をいくつか取れる。デフォルトは1なのでfirstしている
        |> List.first()
        |> get_in(["message", "content"])
      {:error, _error} ->
        # TODO
        "Error !!!"
    end
  end

  def req_post(data) do
    Req.request(
      url: "https://api.openai.com/v1/chat/completions",
      method: :post,
      headers: headers(),
      body: Jason.encode!(data),
      receive_timeout: 60_000
    )
  end

  def build_config("loose" <> _message) do
    %{
      temperature: 1.0,
      presence_penalty: 0.6,
      frequency_penalty: 0.6
    }
  end

  def build_config("tight" <> _message) do
    %{
      temperature: 0.6,
      presence_penalty: 0,
      frequency_penalty: 0
    }
  end

  def build_config(_message) do
    # use default
    %{
      # temperature: 1.0,
      # top_p: 1.0,
      # presence_penalty: 0,
      # frequency_penalty: 0
    }
  end

  defp build_post_data(messages, config) do
    # パラメータ
    # refs: https://platform.openai.com/docs/api-reference/chat/create
    #
    # TODO: 要確認
    #
    # temperature:
    # - [0, 2.0]
    # - デフォルトは1
    # - 小：より関連性の高い単語が選ばれやすくなる
    # - 大：より多様な単語が選ばれやすくなる
    #
    # top_p:
    # - [0, 1.0]
    # - デフォルトは1
    # - 小：より上位にくる単語のみが選択されるため、生成される文章の多様ではなくなる
    # - 大：より多様な単語が選択されるため、生成される文章はより多様になる
    # - temperatureとの併用はNG
    #
    # n:
    # - デフォルトは1
    # - 候補数
    #
    # stop:
    # - string or list
    # - デフォルトはなし
    # - トークンの生成を停止するシーケンスを最大 4 つまで指定できる
    #
    # presence_penalty:
    # - [-2.0, 2.0]
    # - デフォルトは0
    # - 大：既に生成された文章の単語やフレーズにペナルティを与え、多様な文章を促す
    # - 小：ペナルティが小さい
    # - NOTE: マイナスにしたらtimeoutした
    #
    # frequency_penalty:
    # - [-2.0, 2.0]
    # - デフォルトは0
    # - 大：既に生成された文章の頻度にペナルティを与え、同じ行を繰り返す可能性を減らす
    # - 小：ペナルティが小さい
    # - NOTE: マイナスにしたらtimeoutした
    #
    %{
      model: "gpt-3.5-turbo",
      messages: messages,
      n: 1,
      # stop: "。",
    }
    |> Map.merge(config)
  end

  defp headers do
    [
      "Content-type": "application/json",
      Authorization: "Bearer #{chatgpt_token()}"
    ]
  end

  defp chatgpt_token do
    System.get_env("CHATGPT_TOKEN")
  end
end
