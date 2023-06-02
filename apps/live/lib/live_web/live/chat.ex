defmodule LiveWeb.Live.Chat do
  use LiveWeb, :live_view

  alias Chat.{Guid, Cirrus.Socket, Cirrus.Service}
  alias LiveWeb.Components

  require Logger

  @impl true
  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
          <form id="contact_point_form" phx-change="change-contact-point">
            <div class="input-wrapper-entry">
              <input
                type="text"
                value={@input_tenant_id}
                placeholder="enter tenant id"
                name="input-tenant-id"
              />
              <input
                type="text"
                value={@input_contact_point}
                placeholder="enter contact point"
                name="input-contact-point"
              />
            </div>
          </form>
          <form id="contact_point_radio" phx-change="contact-point-radio">
            <div class="input-label">
              <input
                id="choice1"
                type="radio"
                value="0002 KithsiriChat"
                name="contact-point"
                phx-update="ignore"
              />
              <label for="choice1">0002/KithsiriChat</label>
            </div>

            <div class="input-label">
              <input
                id="choice2"
                type="radio"
                value="0002 VladCP"
                name="contact-point"
                phx-update="ignore"
              />
              <label for="choice2">0002/VladCP</label>
            </div>

            <div class="input-label">
              <input
                id="choice3"
                type="radio"
                value="0002 MsgApp"
                name="contact-point"
                phx-update="ignore"
              />
              <label for="choice3">0002/MsgApp</label>
            </div>

            <div class="input-label">
              <input
                id="choice4"
                type="radio"
                value="0003 MsgApp"
                name="contact-point"
                phx-update="ignore"
              />
              <label for="choice4">0003/MsgApp</label>
            </div>
          </form>
          <button id="check" phx-click="check">Check</button>
          <%= if @availability == "open" and @contact_id == nil do %>
            <.live_component
              module={Components.ChatNow}
              id="chat-now"
              chat_now="chat-now"
            />
          <% end %>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(layout: false)
     |> assign(contact_id: nil)
     |> assign(input_contact_point: "")
     |> assign(input_tenant_id: "")
     |> assign(availability: "close")}
  end

  @impl true
  def handle_params(params, uri, socket) do
    Logger.info("receive request #{inspect(uri)} with params #{inspect(params)}")
    tenant_id = Map.get(params, "tenantid")
    contact_point_id = Map.get(params, "contactPointid")
    cid = Map.get(params, "CID")

    socket =
      socket
      |> assign(contact_point_id: contact_point_id)
      |> assign(tenant_id: tenant_id)
      |> assign(cid: cid)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "change-contact-point",
        %{"input-contact-point" => contact_point, "input-tenant-id" => tenant_id},
        socket
      ) do
    {:noreply, socket |> assign(contact_point_id: contact_point) |> assign(tenant_id: tenant_id)}
  end

  @impl true
  def handle_event("contact-point-radio", %{"contact-point" => value}, socket) do
    [tenant_id, contact_point_id] = value |> String.split()

    {:noreply,
     socket
     |> assign(input_contact_point: contact_point_id)
     |> assign(contact_point_id: contact_point_id)
     |> assign(input_tenant_id: tenant_id)
     |> assign(tenant_id: tenant_id)}
  end

  @impl true
  def handle_event("check", _params, socket) do
    %{assigns: %{tenant_id: tenant_id, contact_point_id: contact_point_id}} = socket

    Logger.debug(
      "check tenant_id: #{inspect(tenant_id)}, contact_point_id: #{inspect(contact_point_id)}"
    )

    case Service.call_cirrus_api(tenant_id, contact_point_id, "availability") do
      {:ok, 200, availability} ->
        Logger.info("availability response: #{inspect(availability)}")
        {:noreply, socket |> assign(availability: availability |> Map.get("status"))}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("chat-now", params, socket) do
    Logger.debug("receive chat-now event with params #{inspect(params)}")
    %{assigns: %{tenant_id: tenant_id, contact_point_id: contact_point_id, cid: cid}} = socket

    with {:ok, %{contact_id: contact_id} = data} <-
           Service.get_contact_point(tenant_id, contact_point_id),
         data <- data |> Map.put(:contact_pid, self()) |> Map.put(:cid, cid),
         {:ok, socket_pid} <- Socket.start(data) do
      metadata = [{:tenant, tenant_id}, {:mod, "#{contact_id}|client"}]
      Logger.metadata(metadata)

      Logger.info("cirrus socket connected #{inspect(socket_pid)}")
      Process.monitor(socket_pid)

      {:noreply,
       socket
       |> assign(socket_pid: socket_pid)
       |> assign(contact_id: contact_id)
       |> assign(loading: false)
       |> assign(display: false)}
    else
      error ->
        Logger.error("error while starting the cirrus socket #{inspect(error)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change", %{"input_value" => input_value}, socket) do
    {:noreply, socket |> assign(input_value: input_value)}
  end

  @impl true
  def handle_event("change-layout", _params, socket) do
    file_id = Guid.new()

    url =
      LiveWeb.Router.Helpers.url(socket)
      |> String.replace(~r/:[0-9]+$/, "")
      |> String.replace(~r/^.+:/, "https:")

    {:noreply, socket |> assign(layout: true) |> assign(file_id: file_id) |> assign(url: url)}
  end
end
