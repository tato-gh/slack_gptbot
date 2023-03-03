defmodule SlackGptbot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {
        Bandit,
        plug: SlackGptbot.Plug,
        scheme: String.to_atom(System.get_env("BD_SCHEME")),
        host: String.to_atom(System.get_env("BD_HOST")),
        options: [port: String.to_integer(System.get_env("BD_PORT"))]
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SlackGptbot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
