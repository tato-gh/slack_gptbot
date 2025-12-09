defmodule SlackGptbot.Plug do
  use Plug.Router

  plug :match
  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass:  ["application/json"],
    body_reader: {SlackGptbot.Requests, :read_body, []},
    json_decoder: Jason
  plug :dispatch

  post "/slack/bot" do
    SlackGptbot.Controller.conduct(conn.req_headers, conn.assigns.raw_body, conn.body_params)
    |> case do
      {:ok, body} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(body))
      :error ->
        conn
        |> send_resp(500, "")
    end
  end

  get "/images/:filename" do
    uuid = filename |> Path.rootname() |> Path.basename()

    case SlackGptbot.TempFile.get(uuid) do
      {:ok, binary_data} ->
        content_type = guess_content_type(filename)

        conn
        |> put_resp_content_type(content_type)
        |> send_resp(200, binary_data)

      {:error, :not_found} ->
        send_resp(conn, 404, "Image not found")

      {:error, _reason} ->
        send_resp(conn, 500, "Internal server error")
    end
  end

  defp guess_content_type(filename) do
    case Path.extname(filename) do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      _ -> "application/octet-stream"
    end
  end

  match _ do
    send_resp(conn, 404, "404 Not Found")
  end
end
