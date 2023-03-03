defmodule SlackGptbot.Controller do
  alias SlackGptbot.{Requests, Responses}

  @doc """
  Returns server response data.

  CASE url verification challenge
  see: https://api.slack.com/events/url_verification

  """
  def conduct(req_headers, raw_body, params) do
    with headers = Map.new(req_headers),
         true <- Requests.validate_request(headers, raw_body) do
      _conduct(params)
    else
      _ -> :error
    end
  end

  defp _conduct(%{"type" => "url_verification"} = params) do
    data = Responses.build_reply_to_challenge(params)

    {:ok, data}
  end

  defp _conduct(params) do
    # 非同期実行
    GenServer.cast(SlackGptbot.Bot, {:message, params})

    {:ok, Responses.build_reply(params)}
  end
end
