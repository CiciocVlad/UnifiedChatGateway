defmodule Chat.Message do
  alias Chat.Message.Content

  require Logger

  @send_event "send"
  @relayed_event "relayed"
  @received_event "received"
  @delivered_event "delivered"
  @seen_event "seen"
  @typing_event "typing"
  @end_event "end"
  @disconnect_event "disconnect"
  @system_event "system"
  @customer_event "customer"

  @enforce_keys [:event]
  defstruct [
    :event,
    :tempMessageid,
    :messageid,
    :message,
    :contactid,
    :source,
    :sourceid,
    :name,
    :privacy,
    :timeout,
    :receivedDTZ,
    :sentDTZ,
    :state,
    :eventType,
    :value
  ]

  @type t() :: %__MODULE__{
          event: String.t(),
          tempMessageid: String.t(),
          messageid: String.t(),
          message: [Content.t()],
          contactid: String.t(),
          source: :agent | :system | :customer,
          sourceid: String.t(),
          name: String.t(),
          privacy: String.t(),
          timeout: non_neg_integer(),
          receivedDTZ: String.t(),
          sentDTZ: String.t(),
          state: String.t(),
          eventType: String.t(),
          value: any()
        }

  defguard is_end_event(event) when event === @end_event

  def from_client(json), do: from_client(json, [])

  def from_client(%{"event" => @send_event} = json, opts) do
    %__MODULE__{
      event: @send_event,
      tempMessageid: Map.get(json, "tempMessageid"),
      privacy: Map.get(json, "privacy", "public"),
      message: Content.from_json(Map.get(json, "message", [])),
      source: "customer",
      sourceid: Keyword.get(opts, :client_ip, "customer")
    }
  end

  def from_client(%{"event" => @delivered_event} = json, _opts) do
    messageid = Map.get(json, "messageid")
    contactid = Map.get(json, "contactid")
    delivered_event(messageid, contactid)
  end

  def from_client(%{"event" => @end_event} = json, _opts) do
    %__MODULE__{
      event: @end_event,
      contactid: Map.get(json, "contactid")
    }
  end

  def from_client(%{"event" => @seen_event} = json, _opts) do
    %__MODULE__{
      event: @seen_event,
      messageid: Map.get(json, "messageid"),
      contactid: Map.get(json, "contactid")
    }
  end

  def from_client(%{"event" => @typing_event} = json, _opts) do
    %__MODULE__{
      event: @typing_event,
      contactid: Map.get(json, "contactid"),
      timeout: Map.get(json, "timeout")
    }
  end

  def from_client(%{"event" => @disconnect_event} = json, _opts) do
    %__MODULE__{
      event: @disconnect_event,
      contactid: Map.get(json, "contactid")
    }
  end

  def from_client(%{"event" => @system_event} = json, _opts) do
    %__MODULE__{
      event: @system_event,
      eventType: Map.get(json, "eventType"),
      value: Map.get(json, "value")
    }
  end

  def from_client(unknown, _opts) do
    Logger.warn("received unknown message from client #{inspect(unknown)}")
    nil
  end

  def from_system(json), do: from_system(json, [])

  def from_system(%{"event" => @relayed_event} = json, _opts) do
    %__MODULE__{
      event: @relayed_event,
      messageid: Map.get(json, "messageid"),
      contactid: Map.get(json, "contactid"),
      privacy: Map.get(json, "privacy", "public"),
      message: Content.from_json(Map.get(json, "message", [])),
      source: Map.get(json, "source"),
      sourceid: Map.get(json, "sourceid"),
      name: Map.get(json, "name"),
      receivedDTZ: Map.get(json, "receivedDTZ"),
      state: Map.get(json, "state")
    }
  end

  def from_system(%{"event" => @received_event} = json, _opts) do
    %__MODULE__{
      event: @received_event,
      tempMessageid: Map.get(json, "tempMessageid"),
      privacy: Map.get(json, "privacy", "public"),
      messageid: Map.get(json, "messageid"),
      contactid: Map.get(json, "contactid"),
      source: Map.get(json, "source"),
      sourceid: Map.get(json, "sourceid"),
      name: Map.get(json, "name"),
      sentDTZ: Map.get(json, "sentDTZ"),
      message: Content.from_json(Map.get(json, "message", [])),
      state: Map.get(json, "state")
    }
  end

  def from_system(%{"event" => @delivered_event} = json, _opts) do
    %__MODULE__{
      event: @delivered_event,
      messageid: Map.get(json, "messageid"),
      contactid: Map.get(json, "contactid"),
      state: Map.get(json, "state")
    }
  end

  def from_system(%{"event" => @end_event} = json, _opts) do
    %__MODULE__{
      event: @end_event,
      contactid: Map.get(json, "contactid"),
      state: Map.get(json, "state")
    }
  end

  def from_system(%{"event" => @seen_event} = json, _opts) do
    %__MODULE__{
      event: @seen_event,
      messageid: Map.get(json, "messageid"),
      contactid: Map.get(json, "contactid"),
      state: Map.get(json, "state")
    }
  end

  def from_system(%{"event" => @typing_event} = json, _opts) do
    %__MODULE__{
      event: @typing_event,
      contactid: Map.get(json, "contactid"),
      timeout: Map.get(json, "timeout"),
      state: Map.get(json, "state")
    }
  end

  def from_system(%{"event" => @system_event} = json, _opts) do
    %__MODULE__{
      event: @system_event,
      eventType: Map.get(json, "eventType"),
      value: Map.get(json, "value")
    }
  end

  def from_system(unknown, _) do
    Logger.error("unknown message from system #{inspect unknown}")
    nil
  end

  def to_client(%__MODULE__{
        event: @relayed_event,
        message: message,
        messageid: messageid,
        contactid: contactid,
        source: source,
        sourceid: sourceid,
        name: name,
        receivedDTZ: receivedDTZ,
        state: state
      }) do
    message = Content.to_json(message)

    serialize(%{
      event: @relayed_event,
      message: message,
      messageid: messageid,
      contactid: contactid,
      source: source,
      sourceid: sourceid,
      name: name,
      receivedDTZ: receivedDTZ,
      state: state
    })
  end

  def to_client(%__MODULE__{
        event: @received_event,
        tempMessageid: tempMessageid,
        messageid: messageid,
        contactid: contactid,
        source: source,
        sourceid: sourceid,
        name: name,
        sentDTZ: sentDTZ,
        message: message,
        state: state
      }) do
    message = Content.to_json(message)

    serialize(%{
      event: @received_event,
      tempMessageid: tempMessageid,
      contactid: contactid,
      messageid: messageid,
      message: message,
      source: source,
      sourceid: sourceid,
      name: name,
      sentDTZ: sentDTZ,
      state: state
    })
  end

  def to_client(%__MODULE__{
        event: @delivered_event,
        messageid: messageid,
        contactid: contactid,
        state: state
      }) do
    serialize(%{
      event: @delivered_event,
      contactid: contactid,
      messageid: messageid,
      state: state
    })
  end

  def to_client(%__MODULE__{
        event: @seen_event,
        messageid: messageid,
        contactid: contactid,
        sentDTZ: sentDTZ,
        state: state
      }) do
    serialize(%{
      event: @seen_event,
      contactid: contactid,
      messageid: messageid,
      sentDTZ: sentDTZ,
      state: state
    })
  end

  def to_client(%__MODULE__{
        event: @typing_event,
        messageid: messageid,
        contactid: contactid,
        timeout: timeout,
        sentDTZ: sentDTZ,
        state: state
      }) do
    serialize(%{
      event: @typing_event,
      contactid: contactid,
      messageid: messageid,
      timeout: timeout,
      sentDTZ: sentDTZ,
      state: state
    })
  end

  def to_client(%__MODULE__{
        event: @end_event,
        contactid: contactid,
        state: state
      }) do
    serialize(%{
      event: @end_event,
      contactid: contactid,
      state: state
    })
  end

  def to_client(%__MODULE__{
        event: @system_event,
        eventType: event_type,
        value: value
      }) do
    serialize(%{
      event: @system_event,
      eventType: event_type,
      value: value
    })
  end

  def to_client(unknown_event) do
    Logger.warn("cannot serialize unknown message to send to client #{inspect(unknown_event)}")
    nil
  end

  def to_system(%__MODULE__{
        event: @send_event,
        tempMessageid: tempMessageid,
        privacy: privacy,
        message: message,
        contactid: contactid,
        source: source,
        sourceid: sourceid
      }) do
    serialize(%{
      event: @send_event,
      tempMessageid: tempMessageid,
      privacy: privacy,
      message: Content.to_json(message),
      contactid: contactid,
      source: source,
      sourceid: sourceid
    })
  end

  def to_system(%__MODULE__{
        event: @delivered_event,
        messageid: messageid,
        contactid: contactid
      }) do
    serialize(%{
      event: @delivered_event,
      contactid: contactid,
      messageid: messageid
    })
  end

  def to_system(%__MODULE__{
        event: @seen_event,
        messageid: messageid,
        contactid: contactid,
        sentDTZ: sentDTZ
      }) do
    serialize(%{
      event: @seen_event,
      contactid: contactid,
      messageid: messageid,
      sentDTZ: sentDTZ
    })
  end

  def to_system(%__MODULE__{
        event: @typing_event,
        messageid: messageid,
        contactid: contactid,
        timeout: timeout,
        sentDTZ: sentDTZ
      }) do
    serialize(%{
      event: @typing_event,
      contactid: contactid,
      messageid: messageid,
      timeout: timeout,
      sentDTZ: sentDTZ
    })
  end

  def to_system(%__MODULE__{
        event: @disconnect_event,
        contactid: contactid
      }) do
    serialize(%{
      event: @disconnect_event,
      contactid: contactid
    })
  end

  def to_system(%__MODULE__{event: @end_event, contactid: contactid}) do
    serialize(%{
      event: @end_event,
      contactid: contactid
    })
  end

  def to_system(%__MODULE__{
        event: @system_event,
        eventType: event_type,
        value: value
      }) do
    serialize(%{
      event: @system_event,
      eventType: event_type,
      value: value
    })
  end

  def to_system(%__MODULE__{
        event: @customer_event,
        contactid: contactid,
        eventType: event_type,
        value: value
      }) do
    serialize(%{
      event: @customer_event,
      contactid: contactid,
      eventType: event_type,
      value: value
    })
  end

  def to_system(unknown_event) do
    Logger.warn("cannot serialize unknown message to send to system #{inspect(unknown_event)}")
    nil
  end

  def is_private(%__MODULE__{privacy: privacy}), do: privacy === "private"
  def is_private(_), do: false

  def create_end_event(contactid) do
    %__MODULE__{
      event: @end_event,
      contactid: contactid
    }
  end

  defp serialize(json) do
    json
    |> Enum.filter(fn {_field, value} -> not is_nil(value) end)
    |> Map.new()
  end

  def delivered_event(messageid, contactid) do
    %__MODULE__{
      event: @delivered_event,
      messageid: messageid,
      contactid: contactid
    }
  end

  def send_event(
        messageid,
        contactid,
        format,
        content,
        blockid \\ "",
        navigation \\ "",
        file_id \\ "",
        file_name \\ "",
        size \\ 0,
        ip \\ ""
      ) do
    %__MODULE__{
      event: @send_event,
      message: [
        Content.new(%{
          "format" => format,
          "content" => content,
          "blockid" => blockid,
          "navigation" => navigation,
          "fileid" => file_id,
          "fileName" => file_name,
          "size" => size
        })
      ],
      tempMessageid: messageid,
      contactid: contactid,
      source: "customer",
      sourceid: ip,
      privacy: "public",
      name: "Customer"
    }
  end

  def send_typing_event(contact_id, timeout) do
    %__MODULE__{
      event: @typing_event,
      contactid: contact_id,
      timeout: timeout,
    }
  end

  def send_attachments(messageid, contactid, format, attachments) do
    %__MODULE__{
      event: @send_event,
      message: attachments |> Enum.map(fn attachment -> Content.new(%{"format" => format, "content" => "", "blockid" => "", "navigation" => "", "fileid" => attachment.file_id, "fileName" => attachment.file_name, "size" => 0}) end),
      tempMessageid: messageid,
      contactid: contactid,
      source: "customer",
      sourceid: "",
      privacy: "public",
      name: "Customer"
    }
  end

  defp get_type_of_content(%{"fileName" => file_name, "fileid" => file_id}) do
    %{"format" => "file", "content" => "", "blockid" => "", "navigation" => "", "fileid" => file_id, "fileName" => file_name, "size" => 0}
  end

  defp get_type_of_content(%{"content" => content}) do
    %{"format" => "text", "content" => content}
  end

  def send_attachments_with_messages(messageid, contactid, attachments) do
    %__MODULE__{
      event: @send_event,
      message: Enum.map(attachments, fn attachment -> Content.new(get_type_of_content(attachment)) end),
      tempMessageid: messageid,
      contactid: contactid,
      source: "customer",
      sourceid: "",
      privacy: "public",
      name: "Customer"
    }
  end

  def disconnect_event(contact_id) do
    %__MODULE__{
      event: @disconnect_event,
      contactid: contact_id
    }
  end

  def customer_event(contact_id, event_type, value) do
    %__MODULE__{
      event: @customer_event,
      contactid: contact_id,
      eventType: event_type,
      value: value
    }
  end

  def may_print_content(contactid, messageid, content, blockid \\ nil, navigation \\ nil) do
    msg = decode_message_id(contactid, messageid, blockid, navigation)

    case Application.get_env(:live, :debug, true) do
      true ->
        cond do
          is_bitstring(content) ->
            content =
              if String.length(content) > 200 do
                :binary.part(content, 0, 200) <> "..."
              else
                content
              end

            msg <> ~s(, content: "#{content}")
          is_map(content) ->
            msg <> ~s(, content: "#{inspect content}")
          true ->
            msg
        end

      _ ->
        msg
    end
  end

  def decode_message_id(contactid, messageid, blockid \\ nil, navigation \\ nil)
  def decode_message_id(contactid, messageid, blockid, navigation)
      when contactid != nil and messageid != nil do
    len = byte_size(contactid)
    msg =
      case String.split_at(messageid, len) do
        {^contactid, msg_id} ->
          "(#{msg_id})"

        _ ->
          "(#{messageid})"
      end

    msg =
      if blockid not in [nil, ""] do
        msg <> ", blockid: #{blockid}"
      else
        msg
      end

    if navigation not in [nil, ""] do
      msg <> ", navigation: #{navigation}"
    else
      msg
    end
  end

  def decode_message_id(_, _, _, _) do
    ""
  end
end

defmodule Chat.Message.Content do
  @enforce_keys [:format, :content]
  defstruct [:format, :content, :formid, :blockid, :navigation, :file_name, :file_id, :size, :history]

  @type t() :: %__MODULE__{
          format: String.t(),
          content: String.t(),
          formid: String.t(),
          blockid: String.t(),
          navigation: String.t(),
          file_name: String.t(),
          file_id: String.t(),
          size: Integer.t(),
          history: [String.t()]
        }

  def from_json(json) when is_map(json) do
    new(json)
  end

  def from_json(json) when is_list(json) do
    json
    |> Enum.map(fn
      map when is_map(map) -> from_json(map)
      _ -> nil
    end)
    |> Enum.filter(fn content -> not is_nil(content) end)
  end

  def from_json(_unknown), do: nil

  def to_json(%__MODULE__{
        format: format,
        content: content,
        blockid: blockid,
        navigation: navigation,
        file_name: file_name,
        file_id: file_id,
        size: size,
        history: []
      }) do
    %{
      format: format,
      content: content,
      blockid: blockid,
      navigation: navigation,
      fileName: file_name,
      fileid: file_id,
      size: size
    }
  end

  def to_json(%__MODULE__{
        format: format,
        content: content,
        blockid: blockid,
        navigation: navigation,
        file_name: file_name,
        file_id: file_id,
        size: size,
        history: history
      }) do
    %{
      format: format,
      content: content,
      blockid: blockid,
      navigation: navigation,
      fileName: file_name,
      fileid: file_id,
      size: size,
      history: history
    }
  end

  def to_json(contents) when is_list(contents) do
    contents
    |> Enum.map(fn
      map when is_map(map) -> to_json(map)
      _ -> nil
    end)
    |> Enum.filter(fn content -> not is_nil(content) end)
  end

  def to_json(_unknown), do: nil

  def new(%{"format" => format} = map) do
    if format in Application.get_env(:chat, :message_formats, ["text", "html", "file"]),
      do: %__MODULE__{
        format: Map.get(map, "format", "text"),
        content: Map.get(map, "content", ""),
        formid: Map.get(map, "formid", ""),
        blockid: Map.get(map, "blockid", ""),
        navigation: Map.get(map, "navigation", ""),
        file_name: Map.get(map, "fileName"),
        file_id: Map.get(map, "fileid"),
        size: Map.get(map, "size"),
        history: Map.get(map, "history", [])
      },
      else: nil
  end

  def new(_invalid_data), do: nil
end
