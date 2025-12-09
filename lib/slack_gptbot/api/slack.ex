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
    |> then(fn {:ok, response} -> Map.get(response.body, "ts") end)
  end

  def get_channel_purpose(channel) do
    req_get(
      "https://slack.com/api/conversations.info",
      %{channel: channel}
    )
    |> case do
      {:ok, response} ->
        get_in(response.body, ["channel", "purpose", "value"])
      _ -> ""
    end
  end

  def get_channel_name(channel) do
    req_get(
      "https://slack.com/api/conversations.info",
      %{channel: channel}
    )
    |> case do
      {:ok, response} ->
        get_in(response.body, ["channel", "name"])
      _ -> ""
    end
  end

  def get_channels do
    req_get("https://slack.com/api/conversations.list", %{})
    |> case do
      {:ok, response} ->
        get_in(response.body, ["channels"])
      _ -> []
    end
  end

  def download_file(%{"url_private_download" => url, "mimetype" => mimetype}) do
    require Logger
    Logger.debug("Downloading file from url_private_download: #{url}, mimetype=#{mimetype}")

    with {:ok, response} <- download_from_slack(url),
         _ = Logger.debug("Download response status: #{response.status}, content-type: #{inspect(response.headers["content-type"])}, body size: #{byte_size(response.body)}"),
         {:ok, uuid, public_url} <- SlackGptbot.TempFile.save(response.body, mimetype) do
      Logger.debug("File saved: uuid=#{uuid}, public_url=#{public_url}")
      {:ok, uuid, public_url}
    else
      {:error, reason} ->
        Logger.error("Failed to download file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def download_file(_), do: {:error, :invalid_file_data}

  defp download_from_slack(url) do
    Req.request(
      url: url,
      method: :get,
      headers: [Authorization: "Bearer #{slack_bot_token()}"],
      redirect: true,
      max_redirects: 5
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
