defmodule LiveWeb.Components.StaticForms.LandingPage do
  use LiveWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
        <div class="container" style="margin: 0 auto; padding-left: 20px; padding-right: 20px; width: 375px">
            <div class="spacer" style="height: 255px;"> </div>
            <div class="brand" style="padding: 0; height: 90px; text-align: center;" >
                <img src={@logo}  alt="" height="90px" id="logo"  style="align-self: center; max-width: 100%; height: 100%\" />
            </div>
        </div>
    """
  end
end
