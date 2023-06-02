defmodule LiveWeb.Components.StaticForms.StartPage do
  use LiveWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
        <main class="container" style="margin: 0; width: 100%; display: flex; height: 100%; align-items: center; justify-content: center; position: fixed;">
            <div id="brand" class="brand" style="display: flex; height: 90px; justify-content: center; align-items: center;">
                <img src={@logo} style="align-self: center; max-width: 100%; height: 100%;"/>
            </div>
        </main>
    """
  end
end
