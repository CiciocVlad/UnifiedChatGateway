defmodule LiveWeb.Live.Form do
  use LiveWeb, :live_view

  alias Chat.{Message, Guid, Cirrus.Service, Session, Subscription, RateControl, Moment}
  alias LiveWeb.Components
  alias LiveWeb.Components.StaticForms

  import LiveWeb.CustomForm
  import Phoenix.HTML

  require Logger

  @received "received"

  @configuration %{
    "header" => %{
      "height" => "50px",
      "fill" => "#5b8cc8",
      "fontFamily" => "'Lato', sans-serif",
      "fontSize" => "17px",
      "horizontal" => "left",
      "fontColor" => "#fff",
      "label" => "Live chat"
    },
    "transcript" => %{
      "agentAvatar" => "#333",
      "agentFont" => "#333",
      "agentBubble" => "#9ed1fa",
      "agentBorder" => "#9ed1fa",
      "visitorAvatar" => "#333",
      "visitorFont" => "#333",
      "visitorBubble" => "#d3eafd",
      "visitorBorder" => "#d3eafd",
      "systemAvatar" => "#333",
      "systemFont" => "#333",
      "systemBubble" => "#fff",
      "systemBorder" => "#333",
      "fill" => "#fff"
    },
    "input" => %{
      "fill" => "#fff",
      "fontColor" => "#333",
      "iconColor" => "#a7a7a7",
    },
    "button" => %{
      "icon" => "#fff",
      "fill" => "#5b8cc8"
    },
    "permissions" => %{
      "enableVisitorAttachUpload" => true,
      "displayFooter" => true
    }
   }

  @impl true
  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(%{chat: true} = assigns) do
    ~H"""
      <.live_component
        module={Components.Chat}
        id="chat"
        configuration={@configuration}
        messages={@messages}
        typing={@typing}
        input_value={@input_value}
        send="send"
      />
    """
  end

  def render(%{formid: "unavailablePage"} = assigns) do
    ~H[<.live_component
       id="unavailablePage"
       module={StaticForms.UnavailablePage}
       logo={Routes.static_path(@socket, get_logo(@formid))}
    />]
  end

  def render(%{formid: formid} = assigns) when formid in ["missingPage", nil] do
    ~H[<.live_component
       id="missingPage"
       module={StaticForms.MissingPage}
       logo={Routes.static_path(@socket, get_logo(@formid))}
    />]
  end

  def render(%{formid: "systemExpired"} = assigns) do
    ~H[<.live_component
       id="expired"
       module={StaticForms.ExpiredPage}
       logo={Routes.static_path(@socket, get_logo(@formid))}
    />]
  end

  def render(%{formid: "systemStartPage"} = assigns) do
    ~H[<.live_component
       id="systemStartPage"
       module={StaticForms.StartPage}
       logo={Routes.static_path(@socket, get_logo(@formid))}
       form_data={Jason.encode!(%{"fileid" => @fileid})}
    />]
  end

  def render(%{formid: "systemEndPage"} = assigns) do
    ~H[<.live_component
       id="systemEndPage"
       module={StaticForms.EndPage}
       logo={Routes.static_path(@socket, get_logo(@formid))}
    />]
  end

  def render(%{formid: "systemLanding"} = assigns) do
    ~H[<.live_component
       id="systemLanding"
       module={StaticForms.LandingPage}
       logo={Routes.static_path(@socket, get_logo(@formid))}
    />]
  end

  def render(%{loading: true} = assigns) do
    ~H[<.live_component
       id="loading"
       module={Components.Loading}
       loading={@loading}
       logo={Routes.static_path(@socket, get_logo(@formid))}
       spinner={Routes.static_path(@socket, "/svg/loading.svg")}
    />]
  end

  def render(
        %{
          formid: form_id,
          tenant_id: tenant_id,
          contact_point_id: contact_point_id,
          fileid: file_id
        } = assigns
      ) do
    case get_form(tenant_id, contact_point_id, form_id) do
      {:ok, form} when form not in [nil, ""] ->
        form =
          form
          |> EEx.eval_string(
            no_thanks: "form-response",
            form_data: Jason.encode!(%{"fileid" => file_id})
          )
          |> raw()

        assigns = assign(assigns, :form, form)

        ~H"""
          <%= @form %>
        """

      _ ->
        ~H[<.live_component
           id="missingPage"
           module={StaticForms.MissingPage}
           logo={Routes.static_path(@socket, get_logo(@formid))}
        />]
    end
  end

  @impl true
  def mount(params, _session, socket) do
    ip_address =
      socket
      |> get_connect_info(:peer_data)
      |> Map.get(:address)

    case RateControl.check_rate(:create_subscription, ip_address) do
      :allow ->
        %{"tenantid" => tenant_id} = params

        default_timezone = ChatDb.Database.get_default_timezone(tenant_id)

        client_timezone =
          case get_connect_params(socket) do
            connect_params when connect_params not in [nil, "", []] ->
              Map.get(connect_params, "timezone", default_timezone)

            _ ->
              default_timezone
          end

        configuration =
          case Map.get(socket.assigns, :configuration, nil) do
            conf when conf not in ["", nil, []] ->
              conf

            _ ->
              {:ok, %{"chatConfiguration" => configuration}} =
                read_json(
                  Path.join([:code.priv_dir(:live), "static", "json", "default_styles.json"])
                )

              configuration
          end

        {:ok,
         socket
         |> assign(client_timezone: client_timezone)
         |> assign(form_layout: false)
         |> assign(formid: nil)
         |> assign(loading: true)
         |> assign(availability: "close")
         |> assign(input_value: "")
         |> assign(contact_id: nil)
         |> assign(configuration: configuration)
         |> assign(typing: false)
         |> assign(image: "")
         |> assign(file_size: 0)
         |> assign(path: "")
         |> assign(sent: false)
         |> assign(finish: false)
         |> assign(is_phone: false)
         |> assign(
           ip:
             ip_address
             |> Tuple.to_list()
             |> Enum.join(".")
         )
         |> assign(code: nil)
         |> assign(ended: false)
         |> assign(fileid: nil)
         |> assign(chat: false)
         |> assign(prev_message: {nil, nil})
         |> assign(last_message: {nil, nil})
         |> assign(typing_timeout_ref: nil)
         |> assign(blockid: nil)
         |> assign(font_size: 12), temporary_assigns: [messages: []]}

      _ ->
        Logger.warning("rate limit exceeded #{inspect(ip_address)}")

        {:ok, assign(socket, formid: "systemExpired")}
    end
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{formid: "systemExpired"}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_params(
        %{"tenantid" => tenant_id, "contactPointid" => contact_point_id},
        _uri,
        socket
      ) do
    metadata = [{:tenant, tenant_id}, {:mod, "#{contact_point_id}|client"}]
    Logger.metadata(metadata)

    {:noreply,
     socket
     |> handle_init_request(tenant_id, contact_point_id)
     |> validate_params()}
  end

  @impl true
  def handle_params(
        %{"tenantid" => tenant_id, "runtimeContactPointid" => contact_point_id} = params,
        _uri,
        socket
      ) do
    metadata = [{:tenant, tenant_id}, {:mod, "#{contact_point_id}|client"}]
    Logger.metadata(metadata)

    cid = Map.get(params, "CID")
    socket = socket
    |> handle_runtime_request(tenant_id, contact_point_id, cid)
    |> validate_params()

    socket =
      case socket.assigns do
        %{src_contact_point_id: src_contact_point_id} when src_contact_point_id not in [nil, "", []] ->
          case ChatDb.Database.get_chat_configuration(tenant_id, socket.assigns.src_contact_point_id) do
            %{"chatConfiguration" => chat_configuration} when chat_configuration not in [nil, "", []] ->
              merged_config = Map.merge(socket.assigns.configuration, chat_configuration)

              assign(socket, configuration: merged_config)
            _ ->
              socket
          end
        _ ->
          socket
      end

    {:noreply, socket }
  end

  @impl true
  def handle_params(params, uri, socket) do
    Logger.error("invalid #{uri} parameters #{inspect(params)}")

    {:noreply, assign(socket, formid: "systemExpired")}
  end

  @impl true
  def handle_event("sendtyping", _, socket) do
    send_event = Message.send_typing_event(socket.assigns.contact_id, 5000)

    Subscription.send_to_system(socket.assigns.contact_pid, send_event)
    {:noreply, socket}
  end

  @impl true
  def handle_event("contact-point-radio", %{"contact-point" => value}, socket) do
    [tenant_id, contact_point_id] = String.split(value)

    {:noreply,
     socket
     |> assign(contact_point_id: contact_point_id)
     |> assign(tenant_id: tenant_id)}
  end

  @impl true
  def handle_event("send", %{"input_value" => input_value}, socket) do
    %{
      assigns: %{
        contact_pid: contact_pid,
        contact_id: contact_id
      }
    } = socket

    if input_value != "" do
      send_event =
        Message.send_event(
          Guid.new(),
          contact_id,
          "text",
          input_value
        )

      if Process.alive?(contact_pid) do
        Subscription.send_to_system(contact_pid, send_event)
      else
        {:noreply, socket |> assign(finish: true)}
      end

      {:noreply, socket |> assign(input_value: "")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_document", %{"input_value" => text}, socket) do
    %{assigns: %{contact_pid: contact_pid, contact_id: contact_id}} = socket

    send_event =
      Message.send_attachments_with_messages(
        Guid.new(),
        contact_id,
        text
      )

    if Process.alive?(contact_pid) do
      Subscription.send_to_system(contact_pid, send_event)
    else
      {:noreply, socket |> assign(finish: true)}
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("change-layout", _params, socket) do
    file_id = Guid.new()

    url =
      LiveWeb.Router.Helpers.url(socket)
      |> String.replace(~r/:[0-9]+$/, "")
      |> String.replace(~r/^.+:/, "https:")

    {:noreply,
     socket |> assign(form_layout: true) |> assign(file_id: file_id) |> assign(url: url)}
  end

  @impl true
  def handle_event("send_home", _params, socket) do
    send_photo(socket)
  end

  @impl true
  def handle_event(
        "save_image",
        %{"content" => image, "size" => size, "navigation" => navigation},
        socket
      ) do
    %{
      assigns: %{
        contact_id: contact_id,
        file_id: file_id,
        blockid: blockid,
        contact_pid: contact_pid
      }
    } = socket

    send_event =
      Message.send_event(
        Guid.new(),
        contact_id,
        "formResponse",
        %{"fileid" => file_id},
        blockid,
        navigation
      )

    Subscription.send_to_system(contact_pid, send_event)

    {:reply, %{messageid: socket.assigns.messageid},
     socket |> assign(image: image) |> assign(size: size)}
  end

  @impl true
  def handle_event("restore", %{"content" => image, "size" => size}, socket) do
    {:reply, %{messageid: socket.assigns.messageid},
     socket |> assign(image: image) |> assign(size: size)}
  end

  @impl true
  def handle_event("sent", _params, socket) do
    {:noreply, assign(socket, sent: true)}
  end

  @impl true
  def handle_event("change_font_size", %{"size" => font_size}, socket) do
    {:noreply, assign(socket, font_size: font_size)}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply,
     socket |> assign(image: "") |> assign(form_layout: false) |> push_event("clear", %{})}
  end

  @impl true
  def handle_event(
        "form-response",
        form_response,
        socket
      ) do
    send_form_response(socket, form_response)

    {:noreply, assign(socket, finish: true)}
  end

  @impl true
  def handle_event("send-photo", form_response, socket) do
    send_form_response(socket, form_response)
    send_photo(socket)
  end

  @impl true
  def handle_event("take-another", form_response, socket) do
    send_form_response(socket, form_response)
    {:noreply, socket |> assign(sent: false) |> push_event("clear", %{})}
  end

  @impl true
  def handle_event("finish", form_response, socket) do
    send_form_response(socket, form_response)
    {:noreply, socket |> assign(finish: true) |> push_event("clear", %{})}
  end

  @impl true
  def handle_event("navigation-button", form_response, socket) do
    Logger.debug("received navigation-button event")

    send_form_response(socket, form_response)

    {:noreply, push_event(socket, "clear", %{})}
  end

  @impl true
  def handle_event(event, %{"navigation" => _navigation} = form_response, socket) do
    Logger.debug("received #{event} event")

    send_form_response(socket, form_response)

    {:noreply, push_event(socket, "clear", %{})}
  end

  @impl true
  def handle_event("download", %{"file" => file_id}, socket) do
    %{
      assigns: %{tenant_id: tenant_id, contact_point_id: contact_point_id, contact_id: contact_id}
    } = socket

    Logger.debug("download file #{file_id}")
    Service.download_file(tenant_id, contact_point_id, contact_id, file_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("is_phone", %{"content" => content}, socket) do
    {:noreply, assign(socket, is_phone: content)}
  end

  @impl true
  def handle_event("download_file", %{"file-id" => file_id, "file-name" => file_name }, socket) do
    Logger.info("Download file with file_id: #{file_id}")
    %{
      assigns: %{
        tenant_id: tenant_id,
        contact_point_id: contact_point_id,
        contact_id: contact_id
      }
    } = socket

    case Service.download_file(tenant_id, contact_point_id, contact_id, file_id) do
      {:ok, _, data} ->
        Logger.info("Successfully downloaded file with file_id: #{file_id}")
        {:noreply, push_event(socket, "file-download", %{data: Base.encode64(data), file_name: file_name})}

      {:error, reason} ->
        Logger.error("Failed downloading the file with file_id: #{file_id}. Reason: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_event("save_document", %{"content" => file, "name" => file_name}, socket) do
    file_id = Guid.new()
    %{assigns: %{
      tenant_id: tenant_id,
      contact_point_id: contact_point_id,
      contact_id: contact_id,
      font_size: font_size
    }} = socket

    data = Enum.at(String.split(file, ","), 1)
    decoded_data = Base.decode64!(data)

    Logger.info("Uploading file with file_id: #{file_id}")
    case Service.upload_file_with_content(tenant_id, contact_point_id, contact_id, decoded_data, file_id, file_name) do
      {:ok, 200, _} ->
        embed = ~s(<div class="attached-document" contenteditable="false" phx-value-id="#{file_id}"><p id="#{file_name}" style="font-size: #{font_size}px">#{file_name}</p><button class="remove" id="#{file_id}"><img src=#{Routes.static_path(socket, "/svg/x.svg")} /></button></div>)
        {:reply, %{"file_id" => file_id, "embed" => embed}, socket}

      _ ->
        {:reply, %{"file_id" => nil, "embed" => nil}, socket}
    end
  end

  @impl true
  def handle_event(unhandled, params, socket) do
    Logger.warn("unhandled event #{inspect(unhandled)} with params #{inspect(params)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:push, %Message{messageid: messageid, contactid: contactid} = message},
        socket
      ) do
    delivered_event = Message.delivered_event(messageid, contactid)
    Subscription.send_to_system(socket.assigns.contact_pid, delivered_event)
    socket = handle_message(socket, message)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:DOWN, _reference, :process, pid, reason}, socket) do
    Logger.info("chat session #{inspect(pid)} is terminated with reason #{inspect(reason)}")
    # case reason do
    #   _ when reason in [:normal, {:remote, :closed}] ->
    #     grace_period_timeout = trunc(Application.get_env(:chat, :grace_period_timeout, @default_grace_period_timeout) * 1000)
    #     Process.send_after(self(), :stop_process, grace_period_timeout)
    {:noreply,
     socket
     |> assign(form_layout: false)
     |> assign(image: "")
     |> assign(finish: false)
     |> assign(ended: true)
     |> push_event("clear", %{})}

    #   _ ->
    #     {:stop, :normal, socket}
    # end
  end

  @impl true
  def handle_info(:stop_process, socket) do
    Logger.info("idle timeout fired, stopping the chat session")
    {:stop, :normal, socket}
  end

  @impl true
  def handle_info(:stop_typing, socket) do
    {:noreply, assign(socket, typing: false, typing_timeout_ref: nil)}
  end

  @impl true
  def handle_info(msg, socket) do
    Logger.warn("received unhandled info: #{inspect(msg)}")
    {:noreply, socket}
  end

  defp handle_message(
         socket,
         %Message{event: "typing", messageid: messageid, contactid: contactid} = message
       ) do
    Logger.info("typing event #{Message.decode_message_id(contactid, messageid)}")
    typing_timeout = Map.get(message, :timeout, 5000)

    if socket.assigns.typing_timeout_ref != nil do
      Process.cancel_timer(socket.assigns.typing_timeout_ref)
    end

    typing_timeout_ref = Process.send_after(self(), :stop_typing, typing_timeout)
    assign(socket, typing: true, typing_timeout_ref: typing_timeout_ref)
  end

  defp handle_message(socket, %Message{event: event, messageid: messageid, contactid: contactid})
       when event in ["seen", "delivered"] do
    Logger.info("#{event} event #{Message.decode_message_id(contactid, messageid)}")
    socket
  end

  defp handle_message(socket, %Message{
         event: "system",
         eventType: event_type,
         value: value,
         receivedDTZ: received_dtz
       }) do
    Logger.info("system event #{event_type} #{value} ")
    prev_message = socket.assigns.last_message
    converted_received_time = Moment.get_time(received_dtz, socket.assigns.client_timezone)

    assign(socket,
      messages: [
        create_wrapper(
          socket,
          :system,
          converted_received_time,
          "System",
          "system",
          socket.assigns.configuration,
          "#{event_type}: #{value}",
          prev_message
        )
      ],
      prev_message: prev_message
    )
  end

  defp handle_message(socket, %Message{
         event: event,
         messageid: messageid,
         message: [
           %Chat.Message.Content{
             format: "form",
             formid: formid,
             blockid: blockid
           }
           | _
         ]
       }) do
    %{
      assigns: %{
        tenant_id: tenant_id,
        contact_point_id: contact_point_id
      }
    } = socket

    Logger.info("#{event} event formid: #{formid}, blockid: #{blockid}")

    formid =
      case formid do
        "missingPage" ->
          {:ok, formid} = Service.get_missing_page(tenant_id, contact_point_id)
          formid

        "landingPage" ->
          {:ok, form_id} = Service.get_landing_page(tenant_id, contact_point_id)
          form_id

        _ ->
          formid
      end

    socket
    |> assign(formid: formid)
    |> assign(messageid: messageid)
    |> assign(blockid: blockid)
    |> assign(loading: false)
  end

  defp handle_message(socket, %Message{event: "end", messageid: messageid, contactid: contactid})
       when not socket.assigns.chat do
    Logger.info("end event #{Message.decode_message_id(contactid, messageid)}")
    Session.delete(socket.assigns.contact_pid)
    get_end_page(socket)
  end

  defp handle_message(socket, %Message{
         messageid: messageid,
         contactid: contactid,
         message: [%Chat.Message.Content{content: "This session has ended"} | _]
       })
       when not socket.assigns.chat do
    Logger.info("end event #{Message.decode_message_id(contactid, messageid)}")
    Session.delete(socket.assigns.contact_pid)
    get_end_page(socket)
  end

  defp handle_message(socket, %Message{
         event: @received,
         messageid: messageid,
         contactid: contactid,
         message: [%Chat.Message.Content{format: format} | _]
       })
       when socket.assigns.formid != nil do
    Logger.info(
      "ignore received (#{format}) event #{Message.decode_message_id(contactid, messageid)}"
    )

    socket
  end

  defp handle_message(socket, %Message{
         event: event,
         source: source,
         sourceid: source_id,
         name: name,
         message:
           [%Chat.Message.Content{format: format, content: content} | _] = message_object_list,
         sentDTZ: sent_dtz,
         receivedDTZ: received_dtz,
         messageid: messageid,
         contactid: contactid
       })
       when format in [
              "text",
              "html",
              "file",
              "image",
              "video"
            ] do
    %{
      assigns: %{
        client_timezone: client_timezone,
        last_message: last_message,
        configuration: configuration
      }
    } = socket

    Logger.info(
      "#{event} (#{format}) event #{Message.may_print_content(contactid, messageid, content)}"
    )

    converted_received_time = Moment.get_time(received_dtz, client_timezone)
    prev_message = last_message

    msg =
      cond do
        event == @received ->
          create_wrapper(
            socket,
            :sent,
            converted_received_time,
            name,
            source_id,
            configuration,
            message_object_list,
            prev_message
          )

        source == "system" ->
          create_wrapper(
            socket,
            :system,
            converted_received_time,
            "System",
            source_id,
            configuration,
            message_object_list,
            prev_message
          )

        true ->
          converted_send_time = Moment.get_time(sent_dtz, client_timezone)

          create_wrapper(
            socket,
            :received,
            converted_send_time,
            name,
            source_id,
            configuration,
            message_object_list,
            prev_message
          )
      end

    socket
    |> assign(messages: [msg])
    |> assign(loading: false)
    |> assign(typing: false)
    |> assign(chat: true)
    |> assign(formid: nil)
    |> assign(prev_message: prev_message)
    |> assign(last_message: {source_id, converted_received_time})
  end

  defp handle_message(socket, %Message{
         event: event,
         messageid: messageid,
         contactid: contactid,
         message: message
       }) do
    Logger.warn(
      "unhandled event #{event} #{Message.decode_message_id(contactid, messageid)}, message: #{inspect(message)}"
    )

    socket
  end

  defp get_logo(_) do
    "/svg/system-message-apps-logo.svg"
  end

  defp send_form_response(socket, %{"navigation" => navigation} = form_response) do
    %{assigns: %{contact_id: contact_id, blockid: blockid, contact_pid: contact_pid}} = socket

    form_data =
      case Map.get(form_response, "form_data") do
        form_data when is_map(form_data) ->
          form_data |> Jason.decode!()

        _ ->
          %{}
      end

    send_event =
      Message.send_event(
        Guid.new(),
        contact_id,
        "formResponse",
        form_data,
        blockid,
        navigation
      )

    Subscription.send_to_system(contact_pid, send_event)
  end

  defp send_form_response(_socket, form_response) do
    Logger.warn("invalid form_response: #{inspect(form_response)}")
  end

  defp send_photo(socket) do
    %{
      assigns: %{
        contact_id: contact_id,
        image: image,
        contact_pid: contact_pid,
        file_id: file_id,
        size: size,
        ip: ip
      }
    } = socket

    file_name = "#{file_id}.jpg"

    send_event =
      Message.send_event(
        Guid.new(),
        contact_id,
        "image",
        image,
        "",
        "",
        file_id,
        file_name,
        size,
        ip
      )

    if Process.alive?(contact_pid) do
      Subscription.send_to_system(contact_pid, send_event)
    else
      {:noreply,
       socket |> assign(form_layout: false) |> assign(image: "") |> assign(finish: true)}
    end

    {:noreply,
     socket
     |> assign(form_layout: false)
     |> assign(image: "")
     |> assign(sent: true)
     |> push_event("save", %{
       "tenant_id" => socket.assigns.tenant_id,
       "contact_point_id" => socket.assigns.contact_point_id,
       "contact_id" => socket.assigns.contact_id,
       "url" => socket.assigns.url,
       "file_id" => socket.assigns.file_id
     })}
  end

  defp create_wrapper(socket, type, time_dtz, name, source_id, config, msg, prev_message) do
    id = Guid.new()

    list_item_html = get_list_item_html_by_type(socket, type, id, config, msg)
    {type, list_item_html, time_dtz, id, name, source_id, prev_message}
  end

  defp get_list_item_html_by_type(socket, type, id, config, msg) when is_list(msg) do
    {div_style, p_style} = get_wrapper_styling(type, config)

    message_block =
      Enum.map(msg, fn
        %Chat.Message.Content{format: "file", file_name: file_name, file_id: file_id} ->
          ~s(<div style="padding: 0; display: flex; #{div_style}; background-color: #ecf2f9">
            <p class="file message" style="font-size: #{socket.assigns.font_size}px; display: flex; height: 31px; width: 100%">
              <span id=#{file_id}  class="chat-file-attachment" phx-update="ignore"  phx-click="download_file" phx-value-file-id="#{file_id}" phx-value-file-name="#{file_name}" >
                <span class="file-name">#{file_name}</span>
                <img src=#{Routes.static_path(socket, "/svg/download.svg")} class="download-action">
              </span>
            </p>
          </div>)


        %Chat.Message.Content{format: format, content: content} when format in ["html", "text"] ->
          content = if String.valid?(content), do: content, else: ""
          ~s(<div style="#{div_style}; padding: 0; border: none"><p style="font-size: #{socket.assigns.font_size}px; #{p_style}">#{content}</p></div>)

        _ ->
          ""
      end)
      |> Enum.join()

    case type do
      :sent ->
        ~s(<li id="sent-message-#{id}" class="sent-msg">#{message_block}</li>)

      :received ->
        ~s(<li id="received-message-#{id}" class="received-msg">#{message_block}</li>)

      :system ->
        ~s(<li id="system-message-#{id}" class="system-msg">#{message_block}</li>)
    end
  end

  defp get_list_item_html_by_type(socket, type, id, config, msg) do
    msg = if String.valid?(msg), do: msg, else: ""
    {div_style, p_style} = get_wrapper_styling(type, config)

    case type do
      :sent ->
        ~s(<li id="sent-message-#{id}" class="sent-msg"><p style="font-size: #{socket.assigns.font_size}px; #{p_style}">#{msg}</p></li>)

      :received ->
        ~s(<li id="received-message-#{id}" class="received-msg"><div style="#{div_style}"><p style="font-size: #{socket.assigns.font_size}px; #{p_style}">#{msg}</p></div></li>)

      :system ->
        ~s(<li id="system-message-#{id}" class="system-msg"><div style="#{div_style}"><p style="font-size: #{socket.assigns.font_size}px; #{p_style}">#{msg}</p></div></li>)
    end
  end

  defp get_wrapper_styling(type, config) do
    {background_color, border_color, font_color} =
      case type do
        :sent ->
          {get_transcript_item(config, "visitorBubble"),
           get_transcript_item(config, "visitorBorder"),
           get_transcript_item(config, "visitorFont")}

        :received ->
          {get_transcript_item(config, "agentBubble"), get_transcript_item(config, "agentBorder"),
           get_transcript_item(config, "agentFont")}

        :system ->
          {get_transcript_item(config, "systemBubble"),
           get_transcript_item(config, "systemBorder"), get_transcript_item(config, "systemFont")}
      end

    div_style = "background-color: #{background_color}; border: 1px solid #{border_color}"
    p_style = "word-wrap: break-word; line-height: normal; color: #{font_color}"

    {div_style, p_style}
  end

  defp get_transcript_item(config, name) do
    config
    |> Map.get("transcript", %{})
    |> Map.get(name, "")
  end

  defp handle_runtime_request(socket, tenant_id, contact_point_id, cid) do
    socket =
      socket
      |> assign(contact_point_id: contact_point_id)
      |> assign(tenant_id: tenant_id)
      |> assign(cid: cid)

    case Session.get_contact_point(contact_point_id) do
      {:ok, contact_point_data} ->
        # Page refresh
        socket =
          socket
          |> assign(availability: "open")
          |> get_form_from_cirrus(tenant_id, contact_point_id, contact_point_data)

        if connected?(socket) do
          # Page refresh WebSocket connection
          start_chat_session(socket, contact_point_data)
        else
          # Page refresh GET request
          socket
        end

      _ ->
        # Init request (live URL)
        case Service.get_contact_point(tenant_id, contact_point_id) do
          {:ok, %{src_contact_point_id: src_contact_point_id}} ->
            socket =
              socket
              |> assign(availability: "open")
              |> assign(src_contact_point_id: src_contact_point_id)
              |> get_start_page(src_contact_point_id)

            if connected?(socket) do
              create_chat_session(socket, src_contact_point_id)
            else
              socket
            end

          # If node restarted
          {:ok, %{contact_id: contact_id} = contact_point_data} ->
            socket =
              socket
              |> assign(availability: "open")
              |> get_start_page(contact_point_id)

            if connected?(socket) do
              do_create_chat_session(socket, contact_point_data, contact_id, nil)
            else
              socket
            end

          _ ->
            set_expired(socket)
        end
    end
  end

  defp handle_init_request(socket, tenant_id, contact_point_id) do
    # link URL GET request
    socket =
      socket
      |> assign(contact_point_id: contact_point_id)
      |> assign(tenant_id: tenant_id)
      |> check()

    if socket.assigns.availability == "open" do
      socket
      |> get_start_page(contact_point_id)
      |> redirect_path()
    else
      set_expired(socket)
    end
  end

  defp check(socket) do
    %{assigns: %{tenant_id: tenant_id, contact_point_id: contact_point_id}} = socket

    case Service.call_cirrus_api(tenant_id, contact_point_id, "availability") do
      {:ok, 200, availability} ->
        Logger.info("availability response: #{inspect(availability)}")

        case Map.get(availability, "status", "close") do
          "close" ->
            set_expired(socket)

          status ->
            assign(socket, availability: status)
        end

      _ ->
        set_expired(socket)
    end
  end

  defp redirect_path(socket) do
    %{assigns: %{tenant_id: tenant_id, contact_point_id: orig_contact_point_id}} = socket
    runtime_contact_point = Guid.new()

    case Service.set_runtime_contact_point(
           tenant_id,
           runtime_contact_point,
           orig_contact_point_id
         ) do
      :ok ->
        redirect(socket, to: "/live/#{tenant_id}/#{runtime_contact_point}")

      _ ->
        assign(socket, formid: "unavailablePage")
    end
  end

  defp get_start_page(socket, contact_point_id) do
    %{assigns: %{tenant_id: tenant_id}} = socket

    {:ok, form_id} = Service.get_start_page(tenant_id, contact_point_id)
    Logger.info("init form: #{inspect(form_id)}")

    socket
    |> assign(formid: form_id)
    |> assign(loading: false)
  end

  defp get_end_page(socket) do
    %{assigns: %{tenant_id: tenant_id, contact_point_id: contact_point_id}} = socket

    {:ok, form_id} = Service.get_end_page(tenant_id, contact_point_id)
    Logger.info("end form: #{inspect(form_id)}")

    socket
    |> assign(formid: form_id)
    |> assign(loading: false)
  end

  defp get_form_from_cirrus(socket, tenant_id, contact_point_id, contact_point_data) do
    case Service.call_cirrus_api(tenant_id, contact_point_id, "currentForm") do
      {:ok, 200, %{"formid" => form_id, "blockid" => block_id, "messageid" => message_id}}
      when form_id not in [nil, ""] ->
        Logger.info("runtime form: #{inspect(form_id)}")

        socket
        |> assign(formid: form_id)
        |> assign(messageid: message_id)
        |> assign(blockid: block_id)

      {:error, :contact_point_not_found} ->
        set_expired(socket)

      error ->
        Logger.error(
          "get runtime form from Cirrus failed for contact point: #{contact_point_id}, error: #{inspect(error)}"
        )
        {:ok, form_id} = Service.get_start_page(contact_point_data)
        Logger.info("start form: #{inspect(form_id)}")

        socket
        |> assign(formid: form_id)
        |> assign(loading: false)
    end
  end

  defp create_chat_session(socket, src_contact_point_id) do
    %{assigns: %{tenant_id: tenant_id}} = socket

    case Service.get_contact_point(tenant_id, src_contact_point_id) do
      {:ok, %{contact_id: contact_id} = contact_point_data} ->
        do_create_chat_session(socket, contact_point_data, contact_id, src_contact_point_id)

      error ->
        Logger.error("error while read the contact point #{inspect(error)}")
        socket
    end
  end

  defp do_create_chat_session(socket, contact_point_data, contact_id, src_contact_point_id) do
    %{assigns: %{tenant_id: tenant_id, contact_point_id: contact_point_id, cid: cid}} = socket

    metadata = [{:tenant, tenant_id}, {:mod, "#{contact_id}|client"}]
    Logger.metadata(metadata)

    contact_point_data =
      contact_point_data
      |> Map.put(:contact_point_id, contact_point_id)
      |> Map.put(:cid, cid)

    case Session.create(contact_point_data) do
      {:ok, contact_pid} when is_pid(contact_pid) ->
        Logger.info("chat session created with contact process #{inspect(contact_pid)}")

        contact_point_data = Map.put(contact_point_data, :contact_pid, contact_pid)

        case Session.start(contact_point_data) do
          {:ok, socket_pid} ->
            Logger.info("chat session started with cirrus socket #{inspect(socket_pid)}")
            Subscription.subscribe(contact_pid, "user", self())
            Process.monitor(contact_pid)

            src_contact_point_id != nil and
              Service.may_transit_contact_point(
                tenant_id,
                contact_point_id,
                src_contact_point_id
              )

            socket
            |> assign(contact_pid: contact_pid)
            |> assign(contact_id: contact_id)

          error ->
            Logger.error("error while starting the cirrus socket #{inspect(error)}")
            socket
        end

      error ->
        Logger.error("error while creating the session #{inspect(error)}")
        socket
    end
  end

  defp start_chat_session(
         socket,
         %{tenant_id: tenant_id, contact_id: contact_id, contact_pid: contact_pid} =
           contact_point_data
       ) do
    metadata = [{:tenant, tenant_id}, {:mod, "#{contact_id}|client"}]
    Logger.metadata(metadata)

    case Session.start(contact_point_data) do
      {:ok, socket_pid} ->
        Logger.info("chat session started with cirrus socket #{inspect(socket_pid)}")
        Subscription.subscribe(contact_pid, "user", self())
        Process.monitor(contact_pid)

        socket
        |> assign(contact_pid: contact_pid)
        |> assign(contact_id: contact_id)

      error ->
        Logger.error("error while starting the cirrus socket #{inspect(error)}")
        socket
    end
  end

  defp read_json(file) do
    with {:ok, body} <- File.read(file),
         {:ok, json} <- Poison.decode(body) do
      {:ok, json}
    end
  end

  defp set_expired(socket) do
    %{assigns: %{tenant_id: tenant_id, contact_point_id: contact_point_id}} = socket

    {:ok, form_id} = Service.get_expired_page(tenant_id, contact_point_id)
    Logger.info("expired form: #{inspect(form_id)}")

    socket
    |> assign(formid: form_id)
    |> assign(loading: false)
  end

  defp validate_params(%{assigns: %{formid: nil}} = socket) do
    socket
    |> assign(formid: "missingPage")
    |> assign(loading: false)
  end

  defp validate_params(socket) do
    assign(socket, loading: false)
  end
end
