defmodule SlackGptbot.Controller do
  def receive(_params) do
    %{test: "hoge"}
    |> Jason.encode!()
  end
end
