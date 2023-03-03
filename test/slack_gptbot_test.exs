defmodule SlackGptbotTest do
  use ExUnit.Case
  doctest SlackGptbot

  test "greets the world" do
    assert SlackGptbot.hello() == :world
  end
end
