defmodule ChatDb do
  @moduledoc "ChatDb Application"

  use Application

  def start(_type, _args) do
    pools_opts = Application.get_env(:chat_db, :pools)

    children =
      Enum.map(pools_opts, fn {id, db_args} ->
        %{
          :id => {:cberl_pool, id},
          :start => {:cberl, :start_link, [id | db_args]},
          :restart => :permanent,
          :shutdown => 10_000,
          :type => :worker,
          :modules => [:cberl]
        }
      end)

    opts = [strategy: :one_for_one, name: ChatDb.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
