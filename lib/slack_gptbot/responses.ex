defmodule SlackGptbot.Responses do

  def build_reply_to_challenge(params) do
    %{"challenge" => challenge} = params

    %{challenge: challenge}
  end

  def build_reply(_params), do: %{}
end
