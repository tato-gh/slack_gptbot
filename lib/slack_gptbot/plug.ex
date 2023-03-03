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

  match _ do
    send_resp(conn, 404, "404 Not Found")
  end
end
