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
        ip: parse_ip(System.get_env("BD_IP")),
        port: String.to_integer(System.get_env("BD_PORT"))
      },
      {SlackGptbot.BotDirector, []},
      {SlackGptbot.PostScheduler, []},
      SlackGptbot.Scheduler
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SlackGptbot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp parse_ip(host) when is_binary(host) do
    case host do
      "localhost" -> :loopback
      "0.0.0.0" -> :any
      _ ->
        case :inet.parse_address(String.to_charlist(host)) do
          {:ok, ip} -> ip
          {:error, _} -> :loopback
        end
    end
  end
end
