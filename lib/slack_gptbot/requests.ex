defmodule SlackGptbot.Requests do

  @doc """
  生bodyを保存しておくためのパーサ
  """
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = put_in(conn.assigns[:raw_body], body)
    {:ok, body, conn}
  end

  @doc """
  Slackの想定されているアプリから送信されていることを確認して true/false を返す

  see: https://api.slack.com/authentication/verifying-requests-from-slack
  refs: https://qiita.com/torifukukaiou/items/7c203891144e9ec02d13#verifying-requests-from-slack
  """
  def validate_request(headers, raw_body) do
    req_signature = fetch_signature(headers)
    timestamp = fetch_timestamp(headers)

    validate_timestamp(timestamp) \
    && validate_signature(req_signature, timestamp, raw_body)
  end

  defp validate_timestamp(timestamp) do
    current_time = DateTime.now!("Etc/UTC")

    DateTime.diff(current_time, DateTime.from_unix!(timestamp))
    |> Kernel.abs()
    |> Kernel.<(5 * 60)
  end

  defp validate_signature(req_signature, timestamp, raw_body) do
    my_signature = calc_my_signature(timestamp, raw_body)

    "v0=#{my_signature}" == req_signature
  end

  defp calc_my_signature(timestamp, raw_body) do
    sig_basestring = "v0:" <> Integer.to_string(timestamp) <> ":" <> raw_body

    :crypto.mac(:hmac, :sha256, slack_signing_secret(), sig_basestring)
    |> Base.encode16()
    |> String.downcase()
  end

  defp fetch_timestamp(headers) do
    headers
    |> Map.get("x-slack-request-timestamp")
    |> String.to_integer()
  end

  defp fetch_signature(headers) do
    headers
    |> Map.get("x-slack-signature")
  end

  defp slack_signing_secret do
    System.get_env("SLACK_SIGNING_SECRET")
  end
end
