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

  defp req_post(url, data) do
    Req.request(
      url: url,
      method: :post,
      headers: headers(),
      body: Jason.encode!(data)
    )
  end

  defp headers do
    [
      "Content-type": "application/json",
      Authorization: "Bearer #{slack_bot_token()}"
    ]
  end

  defp slack_bot_token do
    System.get_env("SLACK_BOT_TOKEN")
  end
end
