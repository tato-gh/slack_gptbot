defmodule SlackGptbot.Plug do
  use Plug.Router

  plug :match
  plug :dispatch
  plug Plug.Parsers,
    parsers: [:json],
    pass:  ["application/json"],
    json_decoder: Jason

  post "/slack/events" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, SlackGptbot.Controller.receive(conn.body_params))
  end

  match _ do
    send_resp(conn, 404, "404 Not Found")
  end
end
