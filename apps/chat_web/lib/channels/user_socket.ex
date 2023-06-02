defmodule ChatWeb.UserSocket do
  @behaviour Phoenix.Socket.Transport

  alias Chat.{Session, Subscription, Message}

  alias ChatWeb.JSONSerializer

  require Logger

  import Message, only: [is_end_event: 1]

  @enforce_keys [:contactid]
  defstruct [
    :contactid,
    :contact_pid,
    :client_ip,
    transport: :websocket
  ]

  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: Task, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  def connect(transport_info) do
    Logger.info("Incoming transport info with param #{inspect(transport_info)}")
    # Callback to retrieve relevant data from the connection.
    # The transport_info contains options, params, transport and endpoint keys.
    contactid = Map.get(transport_info.params, "contactid")
    cid = Map.get(transport_info.params, "cid")
    client_ip = get_client_ip(transport_info)

    Logger.debug(
      "socket started by client #{inspect client_ip} with contactid #{inspect(contactid)}"
    )

    case rate_control(client_ip) do
      :allow ->
        case Session.start(contactid, cid) do
          {:ok, contact_pid} ->
            # start cirrus connection

            {:ok,
             %__MODULE__{
               contactid: contactid,
               contact_pid: contact_pid,
               transport: transport_info.transport,
               client_ip: client_ip
             }}

          _error ->
            :error
        end

      :deny ->
        Logger.log(:info, "rate limit exceeded, denying socket creation #{inspect client_ip}")
        :error
    end
  end

  def init(state) do
    %__MODULE__{
      contact_pid: contact_pid,
      transport: transport
    } = state

    # Now we are effectively inside the process that maintains the socket.
    Subscription.subscribe(contact_pid, "user", transport)
    Process.monitor(contact_pid)

    {:ok, state}
  end

  def handle_in({"ping", _opts}, state) do
    # Logger.debug("received ping")
    {:reply, :ok, {:text, "pong"}, state}
  end

  def handle_in({text, opts}, %__MODULE__{client_ip: client_ip} = state) do
    Logger.debug("recv message #{inspect(text)} with opts #{inspect opts}")

    handle_user_message(
      JSONSerializer.decode(text, Keyword.put(opts, :client_ip, client_ip)),
      state
    )
  end

  def handle_in(other, state) do
    Logger.warn("recv unknown message #{inspect(other)}")
    {:ok, state}
  end

  def handle_info({:push, {:text, msg}}, state) do
    Logger.debug("recv process info #{inspect(msg)}")
    handle_proc_message(msg, state)
  end

  def handle_info({:push, msg}, state) do
    Logger.debug("recv process info with message #{inspect(msg)}")
    handle_proc_message(msg, state)
  end

  def handle_info({:end, msg}, state) do
    Logger.info("recv end chat session with details #{inspect(msg)}")
    Process.send_after(self(), :terminated, 500)
    handle_proc_message(msg, state)
  end

  def handle_info(:terminated, state) do
    Logger.info("chat session with customer is terminated")
    {:stop, :normal, state}
  end

  def handle_info(
        {:DOWN, _ref, :process, contact_pid, reason},
        %__MODULE__{contact_pid: contact_pid} = state
      ) do
    Logger.info(
      "[customer ws] recv process down message from #{inspect(contact_pid)} with reason #{inspect reason}"
    )

    Process.send_after(self(), :terminated, 500)

    %__MODULE__{contactid: contactid} = state
    handle_proc_message(Message.create_end_event(contactid), state)
  end

  def handle_info(msg, state) do
    Logger.error("recv unknown process info #{inspect(msg)}")
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp handle_proc_message(message, state) do
    encoded_msg = JSONSerializer.encode!(message)
    {:push, {:text, encoded_msg}, state}
  catch
    error ->
      # FIXME: should reply error for invalid message?
      Logger.warn("cannot encode process message #{inspect message} due to #{inspect error}")
      {:ok, state}
  end

  defp handle_user_message(nil, state), do: {:ok, state}

  defp handle_user_message(
         %Message{event: event} = message,
         %__MODULE__{contact_pid: contact_pid} = state
       )
       when is_end_event(event) do
    Subscription.broadcast(contact_pid, message)

    {:stop, :user_end_session, state}
  end

  defp handle_user_message(message, %__MODULE__{contact_pid: contact_pid} = state) do
    Subscription.broadcast(contact_pid, message)

    {:ok, state}
  end

  defp get_client_ip(%{connect_info: connect_info}) do
    x_forwarded_for =
      connect_info |> Map.get(:x_headers, []) |> List.keyfind("x-forwarded-for", 0)

    case x_forwarded_for do
      nil ->
        peer_address =
          connect_info |> Map.get(:peer_data, %{}) |> Map.get(:address, nil) |> :inet.ntoa()

        case peer_address do
          address when is_list(address) -> to_string(address)
          address when is_binary(address) -> address
          _error -> nil
        end

      {_, client_ip} ->
        client_ip
    end
  end

  defp get_client_ip(_no_connect_info), do: nil

  defp rate_control(nil), do: :allow

  defp rate_control(client_ip) do
    Chat.RateControl.check_rate(:socket_creation, client_ip)
  end
end
