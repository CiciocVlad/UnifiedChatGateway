defmodule Chat.Contact.ProcessSup do
  use DynamicSupervisor

  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_contact_proc(contact_point_data, registry) do
    start_child(Chat.Contact.Process, [contact_point_data, registry])
  end

  def start_child(worker, args) do
    child_spec = %{
      :id => :statistic_sup,
      :start => {worker, :start_link, args},
      :restart => :temporary,
      :shutdown => :brutal_kill,
      :type => :worker
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 100,
      max_seconds: 1
    )
  end
end
