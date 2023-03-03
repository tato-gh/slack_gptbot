defmodule SlackGptbot.API.ChatGPT do

  def init_system_message(message) do
    # その他、メタ設定が必要であれば追加する
    [%{"role" => "system", "content" => message}]
  end

  def add_assistant_message(messages, message) do
    messages ++ [%{"role" => "assistant", "content" => message}]
  end

  def add_user_message(messages, message) do
    messages ++ [%{"role" => "user", "content" => message}]
  end

  def get_message(messages) do
    data = build_post_data(messages)

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
      body: Jason.encode!(data)
    )
  end

  defp build_post_data(messages) do
    %{
      model: "gpt-3.5-turbo",
      messages: messages
    }
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
