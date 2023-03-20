defmodule SlackGptbot.API.Slack do

  def send_reaction(channel, name, timestamp) do
    req_post(
      "https://slack.com/api/reactions.add",
      %{
        channel: channel,
        name: name,
        timestamp: timestamp
      }
    )
  end

  def send_message(message, channel, timestamp) do
    req_post(
      "https://slack.com/api/chat.postMessage",
      %{
        channel: channel,
        text: message,
        thread_ts: timestamp
      }
    )
  end

  def get_channel_purpose(channel) do
    req_get(
      "https://slack.com/api/conversations.info",
      %{
        channel: channel,
      }
    )
    |> case do
      {:ok, response} ->
        get_in(response.body, ["channel", "purpose", "value"])
      _ -> ""
    end
  end

  defp req_post(url, data) do
    Req.request(
      url: url,
      method: :post,
      headers: headers(),
      body: Jason.encode!(data)
    )
  end

  defp req_get(url, data) do
    Req.request(
      url: url,
      method: :get,
      headers: headers(),
      params: data
    )
  end

  defp headers do
    [
      "Content-type": "application/json; charset=UTF-8",
      Authorization: "Bearer #{slack_bot_token()}"
    ]
  end

  defp slack_bot_token do
    System.get_env("SLACK_BOT_TOKEN")
  end
end
