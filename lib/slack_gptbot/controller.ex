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

  defp _conduct(%{"event" => event} = params) do
    conversation = fetch_conversation(event)
    message = fetch_text(event)
    kind = fetch_message_kind(event)

    GenServer.cast(SlackGptbot.BotDirector, {kind, {conversation, message}})
    {:ok, Responses.build_reply(params)}
  end

  defp fetch_conversation(%{"thread_ts" => ts} = event) do
    %{"channel" => channel} = event

    {channel, ts}
  end

  defp fetch_conversation(event) do
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

  # 以下、fetch_message_kind で順番は重要
  # 例えば、bot_idの処理が先にないと下手すると自botのメッセージへの返答処理が動いてしまう

  defp fetch_message_kind(%{"bot_id" => _bot_id}) do
    # bot_idはAppIDとは異なる
    # AppIDを参照するならば`get_in(..., ["bot_profile" , "app_id"])`が必要
    :bot_maybe_myself
  end

  defp fetch_message_kind(%{"type" => "message", "thread_ts" => _ts}) do
    :thread_post
  end

  defp fetch_message_kind(%{"type" => "message", "channel_type" => "im"}) do
    :im_first_post
  end

  defp fetch_message_kind(%{"type" => "app_mention"}) do
    :mention
  end

  defp fetch_message_kind(%{"type" => "message"}) do
    :channel_first_post
  end

  defp fetch_message_kind(_) do
    :unknown
  end
end
