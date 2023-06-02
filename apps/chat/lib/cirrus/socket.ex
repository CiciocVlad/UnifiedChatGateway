defmodule Chat.Cirrus.Socket do
  use WebSockex

  alias Chat.{Session, Subscription, Message}
  # alias LiveWeb.Live.Chat

  require Logger
  import Message, only: [is_end_event: 1]

  @connecting :connecting
  @connected :connected
  @disconnected :disconnected
  @terminating :terminating

  @default_keepalive 20000

  @enforce_keys [:contact_id]
  defstruct [
    :contact_point_id,
    :cirrus_base_url,
    :tenant_id,
    :contact_id,
    :transaction_id,
    :status,
    # :last_call,
    :contact_pid,
    :keepalive,
    :keepalive_ref
    # messages: []
  ]

  ## Visitor Chat API
  def connect(contact_point_id, contact_id, transaction_id, cid) do
    connect!(contact_point_id, contact_id, transaction_id, cid)
  catch
    class, exception ->
      stacktrace = __STACKTRACE__

      Logger.error("#{Exception.format(class, exception, stacktrace)}")
      {:error, :internal_error}
  end

  # Msg Apps API
  def connect(%{contact_id: contact_id} = data) do
    case Registry.lookup(Chat.Cirrus.Registry, contact_id) do
      # already connected
      [{pid, _} | _] ->
        {:ok, pid}

      # not exist
      [] ->
        start(data)
    end
  end

  ## Visitor Chat API
  def connect!(contact_point_id, contact_id, transaction_id, cid) do
    case Registry.lookup(Chat.Cirrus.Registry, contact_id) do
      # already connected
      [{pid, _} | _] ->
        {:ok, pid}

      # not exist
      [] ->
        start(contact_point_id, contact_id, transaction_id, cid)
    end
  end

  ## Visitor Chat API
  def start(contact_point_id, contact_id, transaction_id, cid) do
    case ws_connection_url(contact_point_id, contact_id, transaction_id, cid) do
      {:ok, cirrus_base_url, url} ->
        Logger.info("start connection to cirrus #{url}")

        WebSockex.start(
          url,
          __MODULE__,
          %__MODULE__{
            contact_point_id: contact_point_id,
            cirrus_base_url: cirrus_base_url,
            contact_id: contact_id,
            transaction_id: transaction_id,
            status: @connecting,
            keepalive: Application.get_env(:chat, :cirrus_ws_keepalive, @default_keepalive)
          },
          async: true,
          handle_initial_conn_failure: true
        )

      error ->
        Logger.error("get ws_connection_url error #{inspect(error)}")
        error
    end
  end

  # Msg Apps API
  def start(
        %{
          tenant_id: tenant_id,
          contact_id: contact_id,
          contact_pid: contact_pid,
          contact_point_id: contact_point_id,
          transaction_id: transaction_id
        } = data
      ) do
    case ws_connection_url(data) do
      {:ok, cirrus_base_url, url} ->
        Logger.info("#{tenant_id}|#{contact_id}|socket|start connection to cirrus #{url}")

        WebSockex.start(
          url,
          __MODULE__,
          %__MODULE__{
            contact_point_id: contact_point_id,
            tenant_id: tenant_id,
            cirrus_base_url: cirrus_base_url,
            contact_id: contact_id,
            contact_pid: contact_pid,
            transaction_id: transaction_id,
            status: @connecting,
            keepalive: Application.get_env(:chat, :cirrus_ws_keepalive, @default_keepalive)
          },
          async: true,
          handle_initial_conn_failure: true
        )

      error ->
        error
    end
  end

  # Msg Apps API
  def ws_connection_url(
        %{
          init_type: init_type,
          tenant_id: tenant_id,
          contact_id: contact_id,
          transaction_id: transaction_id,
          contact_point_id: contact_point_id,
          cid: cid,
          cirrus_base_url: cirrus_base_url
        } = data
      )
      when cirrus_base_url != nil do
    ws_url =
      "ws://#{cirrus_base_url}/cirrusapi/#{tenant_id}/#{contact_point_id}/websocket?contactid=#{contact_id}&transactionid=#{transaction_id}"

    ws_url =
      ws_url
      |> may_append_param("cid", cid)
      |> may_append_param("scriptid", Map.get(data, :script_id))
      |> may_append_param("pid", Map.get(data, :cirrus_pid))
      |> may_append_param("initType", init_type)

    {:ok, cirrus_base_url, ws_url}
  end

  def ws_connection_url(data) do
    Logger.error("socket|create url failed, invalid data #{inspect(data)}")
    {:error, :invalid_data}
  end

  ## Visitor Chat API
  def ws_connection_url(contact_point_id, contact_id, transaction_id, cid) do
    case Application.get_env(:chat, :cirrus_base_urls) do
      base_urls when base_urls in [nil, []] ->
        {:error, :undefined_cirrus_base_urls}

      base_urls ->
        [base_url | _] = Enum.shuffle(base_urls)

        ws_url =
          "ws://" <>
            base_url <>
            "/cirrus/contactpoints/#{contact_point_id}/socket/websocket?contactid=#{contact_id}&transactionid=#{transaction_id}"

        {:ok, base_url, may_append_param(ws_url, "cid", cid)}
    end
  end

  def may_append_param(ws_url, _, nil), do: ws_url
  def may_append_param(ws_url, key, value), do: ws_url <> "&#{key}=#{value}"

  # Visitor Chat API
  # Websockex callbacks
  def handle_connect(_conn, %__MODULE__{tenant_id: tenant_id} = self) when tenant_id == nil do
    Logger.debug("Connected!")
    %{contact_id: contact_id, cirrus_base_url: cirrus_base_url} = self
    Registry.register(Chat.Cirrus.Registry, contact_id, @connected)

    self =
      case Session.find(contact_id) do
        {:ok, contact_pid} ->
          Subscription.subscribe(contact_pid, "system", "websocket", cirrus_base_url)
          Process.monitor(contact_pid)
          Map.put(self, :contact_pid, contact_pid)

        _not_found ->
          # TODO: maybe terminate cirrus connection
          self
      end

    self = keepalive_timeout(self)
    {:ok, %__MODULE__{self | status: @connected}}
  end

  # Msg Apps API
  # Websockex callbacks
  def handle_connect(_conn, self) do
    %{tenant_id: tenant_id, contact_id: contact_id, contact_point_id: contact_point_id} = self
    Registry.register(Chat.Cirrus.Registry, contact_id, @connected)

    metadata = [{:tenant, tenant_id}, {:mod, "#{contact_id}|system"}]
    Logger.metadata(metadata)
    Logger.debug("system socket connected!")

    case Session.find(contact_point_id) do
      {:ok, contact_pid} ->
        Subscription.update_system_socket(contact_pid, self())
        Process.monitor(contact_pid)
        Map.put(self, :contact_pid, contact_pid)

        self = keepalive_timeout(self)
        {:ok, %__MODULE__{self | status: @connected}}

      error ->
        Logger.error(
          "contact process (#{contact_point_id}) not found in the session #{inspect(error)}"
        )

        {:close, self}
    end
  end

  def handle_disconnect(_conn, self) do
    Logger.info("system socket disconnected!")

    self = keepalive_cancel(self)

    {:ok, %__MODULE__{self | status: @disconnected}}
  end

  def handle_frame({:text, "pong"}, self) do
    # TODO: remove this log after integrating successfully with cirrus
    # Logger.debug("received pong")
    {:ok, self}
  end

  ## Visitor Chat API
  def handle_frame(
        {:text, msg},
        %__MODULE__{tenant_id: tenant_id, contact_pid: contact_pid} = self
      )
      when tenant_id == nil do
    # Logger.debug("received #{msg}")
    case decode(msg) do
      %Message{event: event} = message ->
        Subscription.broadcast(contact_pid, message)

        case is_end_event(event) do
          true ->
            {:close, self}

          _ ->
            {:ok, self}
        end

      error ->
        Logger.error("message decode error #{inspect(error)}")
        # FIXME: should reply error for invalid message?
        {:ok, self}
    end
  end

  def handle_frame({:text, msg}, %__MODULE__{contact_pid: contact_pid} = self) do
    # Logger.debug("received #{msg}")
    case decode(msg) do
      %Message{event: "system", eventType: "cirrusPid", value: cirrus_pid} ->
        Logger.info("system event cirrusPid: #{cirrus_pid}")
        Session.update_cirrus_pid(contact_pid, cirrus_pid)
        {:ok, self}

      %Message{event: event} = message ->
        Subscription.send_to_users(contact_pid, message)

        case is_end_event(event) do
          true ->
            {:close, self}

          _ ->
            {:ok, self}
        end

      error ->
        Logger.error("message decode error #{inspect(error)}")
        # FIXME: should reply error for invalid message?
        {:ok, self}
    end
  end

  def handle_cast(msg, self) do
    Logger.debug("received unexpected cast msg #{inspect msg}")
    {:ok, self}
  end

  def handle_info(
        {:push,
         %Message{event: event, messageid: messageid, tempMessageid: tempMessageid, message: msg} =
           message},
        self
      ) do
    %__MODULE__{contact_id: contact_id} = self

    messageid = if messageid == nil, do: tempMessageid, else: messageid

    case msg do
      [
        %Chat.Message.Content{
          format: format,
          content: content,
          blockid: blockid,
          navigation: navigation
        }
        | _
      ] ->
        Logger.info(
          "#{event} (#{format}) event #{Message.may_print_content(contact_id, messageid, content, blockid, navigation)}"
        )

      _ ->
        Logger.info("#{event} event #{Message.decode_message_id(contact_id, messageid)}")
    end

    case encode(message) do
      nil ->
        {:ok, self}

      encoded_msg ->
        {:reply, {:text, encoded_msg}, self}
    end
  end

  def handle_info(:keepalive, self) do
    # TODO: remove this log after integrating successfully with cirrus
    # Logger.debug("receive keepalive timeout - send ping")
    {:reply, {:text, "ping"}, keepalive_timeout(self)}
  end

  def handle_info(:terminated, self) do
    Logger.debug("chat session with cirrus is terminated")
    {:close, %__MODULE__{self | status: @terminating}}
  end

  def handle_info(
        {:DOWN, _ref, :process, pid, reason},
        %__MODULE__{contact_pid: contact_pid} = self
      )
      when pid == contact_pid do
    Logger.info(
      "receive user process #{inspect(contact_pid)} down message with reason #{inspect reason}"
    )

    {:close, %__MODULE__{self | status: @terminating}}
    # close_msg = contact_id |> Message.create_end_event() |> encode()
    # Process.send_after(self(), :terminated, 500)

    # Logger.debug("end message #{inspect(close_msg)}")
    # {:reply, {:text, close_msg}, self}
  end

  def handle_info(msg, self) do
    Logger.debug("receive unexpected info message #{inspect msg}")
    {:ok, self}
  end

  def handle_ping(_ping, self) do
    {:reply, :pong, self}
  end

  defp keepalive_timeout(%__MODULE__{keepalive: keepalive} = self) do
    keepalive_ref = Process.send_after(self(), :keepalive, keepalive)
    %__MODULE__{self | keepalive_ref: keepalive_ref}
  end

  defp keepalive_cancel(%__MODULE__{keepalive_ref: keepalive_ref} = self)
       when is_reference(keepalive_ref) do
    Process.cancel_timer(keepalive_ref)
    self
  end

  defp keepalive_cancel(self), do: self

  defp encode(message, default \\ nil) do
    case Jason.encode(Message.to_system(message)) do
      {:ok, encoded_msg} ->
        encoded_msg

      error ->
        Logger.debug("error on encoding message #{inspect(error)}")
        default
    end
  end

  defp decode(origin_message, default \\ nil) do
    case Jason.decode(origin_message) do
      {:ok, message} ->
        Message.from_system(message)

      error ->
        Logger.error("cannot decode message from cirrus #{inspect(error)}")
        default
    end
  end
end
