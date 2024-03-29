defmodule SlackGptbot.MixProject do
  use Mix.Project

  def project do
    [
      app: :slack_gptbot,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SlackGptbot.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, ">= 0.6.9"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.3"},
      {:quantum, "~> 3.0"}
    ]
  end
end
