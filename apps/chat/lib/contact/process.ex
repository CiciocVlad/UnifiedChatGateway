defmodule Chat.Contact.Process do
  use GenServer

  alias Chat.{Moment, Guid, Message, Message.Content, Cirrus.Service, Table}
  alias ChatDb.Database

  require Logger

  import Message, only: [is_end_event: 1, is_private: 1]

  @client_source "customer"
  @system_source "system"
  @relayed_event "relayed"
  @configuration "configuration"

  @enforce_keys [:contact_id]
  defstruct [
    :tenant_id,
    :contact_point_id,
    :contact_id,
    :transaction_id,
    :idle_timeout,
    :last_call,
    :system_socket,
    subscribers: %{},
    messages: [],
    config_event: nil,
    contact_point_data: %{}
  ]

  def start_link(contact_point_data, registry) do
    GenServer.start_link(__MODULE__, contact_point_data, name: registry)
  end

  def subscribe(pid, subscriber_pid, type, transport, cirrus_base_url) do
    case type do
      "system" ->
        GenServer.cast(
          pid,
          {:subscribe, subscriber_pid, transport, @system_source, cirrus_base_url}
        )

      _ ->
        GenServer.cast(
          pid,
          {:subscribe, subscriber_pid, transport, @client_source, cirrus_base_url}
        )
    end
  end

  def broadcast(pid, subscriber_pid, %Message{} = message) do
    GenServer.cast(pid, {:broadcast, subscriber_pid, message})
  end

  def update_system_socket(pid, system_socket) do
    GenServer.cast(pid, {:update_system_socket, system_socket})
  end

  def send_to_system(pid, %Message{} = message) do
    GenServer.cast(pid, {:send_to_system, message})
  end

  def send_to_users(pid, %Message{} = message) do
    GenServer.cast(pid, {:send_to_users, message})
  end

  def contact_info(pid) do
    GenServer.call(pid, :contact_info)
  end

  def proc_info(pid) do
    GenServer.call(pid, :proc_info)
  end

  def get_cirrus_base_url(pid) do
    GenServer.call(pid, :get_cirrus_base_url)
  end

  def get_contact_point(pid) do
    GenServer.call(pid, :get_contact_point)
  end

  def update_cirrus_pid(pid, cirrus_pid) do
    GenServer.cast(pid, {:update_cirrus_pid, cirrus_pid})
  end

  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  @impl GenServer
  def init([contact_point_id, contact_id]) do
    do_init(%{
      tenant_id: nil,
      contact_point_id: contact_point_id,
      contact_id: contact_id,
      transaction_id: Guid.new()
    })
  end

  @impl GenServer
  def init(contact_point_data) do
    do_init(contact_point_data)
  end

  def do_init(
        %{
          tenant_id: tenant_id,
          contact_point_id: contact_point_id,
          contact_id: contact_id,
          transaction_id: transaction_id
        } = contact_point_data
      ) do
    Table.create(contact_point_id)

    self = %__MODULE__{
      tenant_id: tenant_id,
      contact_point_id: contact_point_id,
      contact_id: contact_id,
      transaction_id: transaction_id,
      contact_point_data: contact_point_data,
      last_call: Moment.system_now_ms(),
      subscribers: %{},
      idle_timeout: trunc(Application.get_env(:chat, :contact_proc_idle_timeout, 300) * 1000)
    }

    metadata = [{:tenant, tenant_id}, {:mod, "#{contact_id}|process"}]
    Logger.metadata(metadata)

    {:ok, restart_idle_timer(self)}
  end

  @impl GenServer
  # For testing
  def handle_call(:proc_info, _from, self) do
    {:reply, self, %__MODULE__{self | last_call: Moment.system_now_ms()}}
  end

  def handle_call(
        :contact_info,
        _from,
        %__MODULE__{contact_point_id: contact_point_id, transaction_id: transaction_id} = self
      ) do
    {:reply, {contact_point_id, transaction_id},
     %__MODULE__{self | last_call: Moment.system_now_ms()}}
  end

  def handle_call(:get_cirrus_base_url, _from, self = %__MODULE__{subscribers: subscribers}) do
    reply =
      case Enum.find(subscribers, fn {_, %{source: source}} -> source == @system_source end) do
        {_, %{cirrus_base_url: cirrus_base_url}} ->
          {:ok, cirrus_base_url}

        _ ->
          {:error, :not_found}
      end

    {:reply, reply, self}
  end

  def handle_call(
        :get_contact_point,
        _from,
        self = %__MODULE__{contact_point_data: contact_point_data}
      ) do
    contact_point_data = Map.put(contact_point_data, :contact_pid, self())
    {:reply, {:ok, contact_point_data}, self}
  end

  def handle_call(request, from, self) do
    Logger.error("unexpected handle_call #{inspect(request)} #{inspect(from)}")
    {:reply, :error, self}
  end

  @impl GenServer
  def handle_cast({:update_system_socket, system_socket}, self) do
    %__MODULE__{messages: messages} = self
    Logger.info("update_system_socket #{inspect(system_socket)}")
    Logger.debug("pending messages #{inspect(messages)}")
    Enum.map(Enum.reverse(messages), fn message -> send(system_socket, {:push, message}) end)
    {:noreply, %__MODULE__{self | system_socket: system_socket, messages: []}}
  end

  @impl GenServer
  def handle_cast({:update_cirrus_pid, cirrus_pid}, self) do
    Logger.info("update_cirrus_pid #{inspect(cirrus_pid)}")
    %__MODULE__{contact_point_data: contact_point_data} = self
    contact_point_data = Map.put(contact_point_data, :cirrus_pid, cirrus_pid)
    Service.transit_offline_contact_point(contact_point_data)

    self = %__MODULE__{self | contact_point_data: contact_point_data}
    {:noreply, self}
  end

  @impl GenServer
  def handle_cast({:subscribe, subscriber_pid, transport, source, cirrus_base_url}, self) do
    self =
      self
      |> do_subscribe(subscriber_pid, transport, source, cirrus_base_url)
      |> Map.put(:last_call, Moment.system_now_ms())

    may_push_config_event(self, subscriber_pid, source)

    {:noreply, self}
  end

  def handle_cast({:broadcast, from_pid, %Message{event: event} = message}, self)
      when is_end_event(event) do
    %__MODULE__{subscribers: subscribers} = self
    Logger.info("recv end message #{inspect(message)} from #{inspect(from_pid)}")

    # broadcast to all subscribers except from_pid
    case Map.get(subscribers, from_pid) do
      %{} ->
        subscribers
        |> Enum.reduce([], fn
          {pid, _}, acc when pid !== from_pid -> [pid | acc]
          _, acc -> acc
        end)
        |> do_broadcast(message, :end)

        # TODO: maybe terminate contact process or wait in configured time before termiating process
        {:stop, :normal, self}

      _unknown ->
        Logger.error("recv end message from unsubscribed client #{inspect(from_pid)}")
        {:noreply, self}
    end
  end

  def handle_cast({:broadcast, from_pid, message}, self) do
    %__MODULE__{subscribers: subscribers} = self
    # Logger.debug("recv new message #{inspect(message)} from #{inspect(from_pid)}")

    # TODO: broadcast to all subscribers that have different source value (system | customer) or broadcast to all (system/customer) subs???
    case Map.get(subscribers, from_pid) do
      %{source: from_source} ->
        case is_private(message) and from_source === @system_source do
          true ->
            Logger.info("recv private message from system #{inspect(from_pid)} - no broadcast")

          false ->
            subscribers
            |> Enum.reduce([], fn
              {pid, %{source: dest_source}}, acc when dest_source !== from_source -> [pid | acc]
              _, acc -> acc
            end)
            |> do_broadcast(message)
        end

      _unknown ->
        Logger.error("recv message from unsubscribed client #{inspect(from_pid)}")
    end

    self = may_cache_config_event(self, message)

    {:noreply, Map.put(self, :last_call, Moment.system_now_ms())}
  end

  def handle_cast({:send_to_users, %Message{event: event} = message}, self) do
    %__MODULE__{subscribers: subscribers} = self

    case is_private(message) do
      true ->
        Logger.info("client> ignore private message from system")

      false ->
        subscribers
        |> Map.keys()
        |> do_broadcast(message)
    end

    case is_end_event(event) do
      true ->
        Logger.info("received end message")
        {:stop, :normal, self}

      _ ->
        self = may_cache_config_event(self, message)
        {:noreply, Map.put(self, :last_call, Moment.system_now_ms())}
    end
  end

  def handle_cast({:send_to_system, message}, self) do
    %__MODULE__{system_socket: system_socket, messages: messages} = self

    self =
      if is_pid(system_socket) do
        send(system_socket, {:push, message})
        self
      else
        Logger.error("send message #{inspect(message)} to system failed, socket: #{inspect(system_socket)}")
        %__MODULE__{self | messages: [message | messages]}
      end

    {:noreply, Map.put(self, :last_call, Moment.system_now_ms())}
  end

  def handle_cast(:stop, self) do
    Logger.info("received stop event")
    {:stop, :normal, self}
  end

  def handle_cast(msg, self) do
    Logger.error("unexpected message #{inspect(msg)}")
    {:noreply, self}
  end

  @impl GenServer
  def handle_info({:DOWN, _subscriber_ref, :process, subscriber_pid, reason}, self) do
    %__MODULE__{subscribers: subscribers, contact_id: contact_id} = self

    case Map.get(subscribers, subscriber_pid) do
      %{transport: transport} ->
        Logger.info(
          "subscriber process #{inspect(subscriber_pid)} (transport #{inspect(transport)}) down with reason #{inspect(reason)}"
        )

        customer_event = Message.customer_event(contact_id, "status", "inactive")
        send_to_system(self(), customer_event)

        {:noreply, %__MODULE__{self | subscribers: Map.delete(subscribers, subscriber_pid)}}

      _ ->
        Logger.warn(
          "unknown terminatin of subscriber process #{inspect(subscriber_pid)} with reason #{inspect(reason)}"
        )

        {:noreply, self}
    end
  end

  def handle_info(:stop_process, self) do
    %__MODULE__{contact_id: contact_id, last_call: last_call, idle_timeout: idle_timeout} = self
    last_call = if is_nil(last_call), do: 0, else: last_call

    Logger.debug(
      "validate idle timer for #{inspect(contact_id)} - last call #{last_call} - now #{Moment.system_now_ms()} - #{idle_timeout}"
    )

    if Moment.system_now_ms() - last_call > idle_timeout do
      Logger.info("process idle timer for #{inspect(contact_id)} expired")
      {:stop, :normal, self}
    else
      {:noreply, restart_idle_timer(self)}
    end
  end

  def handle_info(msg, self) do
    Logger.error("unexpected message #{inspect(msg)}")
    {:noreply, self}
  end

  @impl GenServer
  def terminate(reason, self) do
    %__MODULE__{tenant_id: tenant_id, contact_point_id: contact_point_id} = self

    if tenant_id != nil do
      Database.delete_contact_point(tenant_id, contact_point_id)
      Table.delete(contact_point_id)
    end
    Logger.debug("terminating with reason #{inspect(reason)}")
  end

  defp restart_idle_timer(%__MODULE__{idle_timeout: idle_timeout} = self) do
    Logger.debug("restart idle timer ater #{idle_timeout}")
    Process.send_after(self(), :stop_process, idle_timeout)
    self
  end

  defp do_broadcast(subscribers, message, type \\ :push) do
    # Logger.debug("broadcast message to #{inspect subscribers}")

    Enum.map(subscribers, fn subscriber_pid ->
      send(subscriber_pid, {type, message})
    end)
  end

  defp do_subscribe(self, subscriber_pid, transport, source_from, cirrus_base_url) do
    %__MODULE__{subscribers: subscribers, contact_id: contact_id} = self

    Logger.info(
      "recv #{inspect(source_from)} subscribe request from #{inspect(subscriber_pid)} with transport #{inspect(transport)}"
    )

    Process.monitor(subscriber_pid)

    customer_event = Message.customer_event(contact_id, "status", "active")
    send_to_system(self(), customer_event)

    subscribers =
      Map.put(subscribers, subscriber_pid, %{
        transport: transport,
        source: source_from,
        cirrus_base_url: cirrus_base_url
      })

    %__MODULE__{self | subscribers: subscribers}
  end

  defp may_cache_config_event(
         self,
         %{
           source: @system_source,
           event: @relayed_event,
           message: [%Content{format: @configuration}]
         } = message
       ) do
    %__MODULE__{self | config_event: message}
  end

  defp may_cache_config_event(self, _), do: self

  defp may_push_config_event(%__MODULE__{config_event: config_event}, pid, @client_source)
       when config_event != nil do
    send(pid, {:push, config_event})
  end

  defp may_push_config_event(_self, _pid, _source), do: :ok
end
