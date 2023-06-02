defmodule ChatWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # import Supervisor.Spec

    children = [
      # Start the Endpoint (http/https)
      # supervisor(ChatWeb.Endpoint, []),
      # Start a worker by calling: Chat.Worker.start_link(arg)
      # {Chat.Worker, arg}
      %{
        :id => ChatWeb.Endpoint,
        :start => {ChatWeb.Endpoint, :start_link, []},
        :type => :supervisor,
        :modules => [ChatWeb.Endpoint]
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ChatWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
