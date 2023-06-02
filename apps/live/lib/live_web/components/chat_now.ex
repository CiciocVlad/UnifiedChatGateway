defmodule LiveWeb.Components.ChatNow do
  use LiveWeb, :live_component

  @impl true
  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="wrapper">
      <div class="top-box">
        <h1>Chat now</h1>
        <button class="close">x</button>
      </div>
      <div class="middle-box">
        <h1>We are online.</h1>
        <h1>Need help?</h1>
      </div>
      <div class="bottom-box">
        <button id="chat" phx-click={@chat_now} style="background-color: blue">
          Chat now
        </button>
      </div>
    </div>
    """
  end
end
