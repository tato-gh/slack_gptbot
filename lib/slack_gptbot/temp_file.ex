defmodule SlackGptbot.TempFile do
  @moduledoc """
  一時画像ファイルの保存・取得・削除を管理するモジュール
  """

  @temp_dir "priv/static/temp_images"

  @doc """
  一時ディレクトリを初期化する
  """
  def ensure_temp_dir do
    File.mkdir_p!(@temp_dir)
  end

  @doc """
  画像バイナリデータを一時ファイルとして保存し、UUIDと公開URLを返す
  """
  def save(binary_data, mimetype) do
    ensure_temp_dir()

    uuid = generate_uuid()
    extension = mimetype_to_extension(mimetype)
    filename = "#{uuid}.#{extension}"
    filepath = Path.join(@temp_dir, filename)

    case File.write(filepath, binary_data) do
      :ok -> {:ok, uuid, build_public_url(filename)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_uuid do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  @doc """
  UUIDに対応する一時ファイルを取得する
  """
  def get(uuid) do
    filepath = find_file_by_uuid(uuid)

    case filepath do
      nil -> {:error, :not_found}
      path -> File.read(path)
    end
  end

  @doc """
  UUIDに対応する一時ファイルを削除する
  """
  def delete(uuid) when is_binary(uuid) do
    filepath = find_file_by_uuid(uuid)

    case filepath do
      nil -> {:error, :not_found}
      path -> File.rm(path)
    end
  end

  def delete(_), do: :ok

  defp find_file_by_uuid(uuid) do
    Path.wildcard(Path.join(@temp_dir, "#{uuid}.*"))
    |> List.first()
  end

  defp mimetype_to_extension("image/jpeg"), do: "jpg"
  defp mimetype_to_extension("image/jpg"), do: "jpg"
  defp mimetype_to_extension("image/png"), do: "png"
  defp mimetype_to_extension("image/gif"), do: "gif"
  defp mimetype_to_extension("image/webp"), do: "webp"
  defp mimetype_to_extension(_), do: "jpg"

  defp build_public_url(filename) do
    base_url = System.get_env("SERVER_BASE_URL", "http://localhost:4000")
    "#{base_url}/images/#{filename}"
  end

  @doc """
  古い一時ファイルを削除する（1時間以上経過したもの）
  """
  def cleanup_old_files do
    ensure_temp_dir()

    Path.wildcard(Path.join(@temp_dir, "*"))
    |> Enum.each(fn filepath ->
      case File.stat(filepath) do
        {:ok, %File.Stat{mtime: mtime}} ->
          file_time = :calendar.datetime_to_gregorian_seconds(mtime)
          current_time = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())

          if current_time - file_time > 3600 do
            File.rm(filepath)
          end

        _ ->
          :ok
      end
    end)
  end
end
