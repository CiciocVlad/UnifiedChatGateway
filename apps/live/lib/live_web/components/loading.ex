defmodule LiveWeb.Components.Loading do
  use LiveWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
        <div class="wrapper" style={if @loading, do: "height: 100%; grid-template-rows: 50px 1fr; width: 100%; display: flex; flex-direction: column; padding: 0 20px 20px;"}>
            <div class="brand" style="display: flex; height: 90px; justify-content: center; align-items: center; padding: 20px 0">
                <img id="logo" src={@logo} style="align-self: center; max-width: 100%; height: 100%;" />
            </div>
            <div class="center">
                <div class="ring">
                    <img id="loading" src={@spinner} alt="loading" />
                    <p style="margin-top: 0;">Loading...</p>
                </div>
            </div>
        </div>
    """
  end
end
