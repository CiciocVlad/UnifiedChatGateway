defmodule ChatWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :chat_web

  socket "/chat/contacts/:contactid/socket", ChatWeb.UserSocket,
    websocket: [
      connect_info: [:peer_data, :x_headers],
      timeout: 60_000
    ],
    longpoll: true

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug RemoteIp, clients: ~w[10.3.255.0/24]
  plug ChatWeb.Router
end
