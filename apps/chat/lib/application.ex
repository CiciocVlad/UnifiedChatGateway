defmodule Chat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      %{
        :id => Chat.Contact.Registry,
        :start => {Registry, :start_link, [[keys: :unique, name: Chat.Contact.Registry]]},
        :restart => :permanent,
        :modules => [Registry]
      },
      %{
        :id => Chat.Cirrus.Registry,
        :start => {Registry, :start_link, [[keys: :unique, name: Chat.Cirrus.Registry]]},
        :restart => :permanent,
        :modules => [Registry]
      },
      %{
        :id => Chat.Contact.ProcessSup,
        :start => {Chat.Contact.ProcessSup, :start_link, []},
        :type => :supervisor,
        :modules => [Chat.Contact.ProcessSup]
      }
    ]

    opts = [strategy: :one_for_one, name: Chat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
