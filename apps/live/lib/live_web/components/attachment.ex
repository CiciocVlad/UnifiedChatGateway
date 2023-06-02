defmodule LiveWeb.Components.Attachment do
  use LiveWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="attachment" contenteditable="false">
      <p><%= @file_name %></p>
      <img src="/svg/x.svg" phx-value-id={@file_id} />
    </div>
    """
  end
end
