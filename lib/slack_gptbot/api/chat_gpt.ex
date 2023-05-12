defmodule SlackGptbot.API.ChatGPT do
  @doc """
  初回のユーザー発言に対する返信内容を返す
  """

  @default_model "gpt-3.5-turbo"

  def create_first_messages(prompt, message) do
    init_system_message(prompt)
    |> add_user_message(message)
    |> elem(1)
  end

  defp init_system_message("") do
    []
  end

  defp init_system_message(message) do
    [%{"role" => "system", "content" => message}]
  end

  def add_assistant_message(messages, message) do
    messages ++ [%{"role" => "assistant", "content" => message}]
  end

  def add_user_message(messages, "!" <> _rest), do: {:nothing, messages}

  def add_user_message(messages, "コメント" <> _rest), do: {:nothing, messages}

  def add_user_message([system | _rest], "---"), do: {:nothing, [system]}

  def add_user_message([system | _rest], "リセット"), do: {:nothing, [system]}

  def add_user_message([system | _rest], "---" <> rest) do
    add_user_message([system], rest)
  end

  def add_user_message(messages, "") do
    {:empty, messages}
  end

  def add_user_message(messages, message) do
    {:ok, messages ++ [%{"role" => "user", "content" => message}]}
  end

  def get_message(messages, config \\ %{}) do
    data = build_post_data(messages, config)

    case req_post(data) do
      {:ok, response} ->
        response.body
        |> Map.get("choices")
        # 設定によって回答候補をいくつか取れる。デフォルトは1なのでfirstしている
        |> List.first()
        |> get_in(["message", "content"])
      {:error, error} ->
        "Error: #{error.reason}"
    end
  end

  def req_post(data) do
    Req.request(
      url: "https://api.openai.com/v1/chat/completions",
      method: :post,
      headers: headers(),
      body: Jason.encode!(data),
      receive_timeout: 300_000
    )
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
      model: @default_model,
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
