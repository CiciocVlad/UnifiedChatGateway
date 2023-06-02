defmodule ChatWeb.JSONSerializer do
  alias Chat.Message
  require Logger

  def encode!(%Message{} = msg) do
    data = Message.to_client(msg)
    Phoenix.json_library().encode_to_iodata!(data)
  end

  def encode(message, default \\ nil) do
    encode!(message)
  catch
    error ->
      # FIXME: should reply error for invalid message?
      Logger.warn("cannot encode message #{inspect message} due to #{inspect error}")
      default
  end

  def decode!(raw_message, opts) do
    map = Phoenix.json_library().decode!(raw_message)
    Message.from_client(map, opts)
  end

  def decode(raw_message, opts \\ []) do
    decode!(raw_message, opts)
  catch
    error ->
      Logger.error(
        "cannot decode raw message #{inspect(raw_message)} to json due to #{inspect(error)}"
      )

      nil
  end
end
