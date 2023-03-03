defmodule SlackGptbot.API.ChatGPT do

  def init_system_message(message) do
    # その他、メタ設定が必要であれば追加する
    [%{"role" => "system", "content" => message}]
  end

  def add_assistant_message(messages, message) do
    messages ++ [%{"role" => "assistant", "content" => message}]
  end

  def add_user_message(messages, message) do
    messages ++ [%{"role" => "user", "content" => message}]
  end

  def get_message(messages) do
    # TODO: 後ほど
    "hoge"
  end
end
