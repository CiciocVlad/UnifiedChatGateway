defmodule LiveWeb.Components.StaticForms.UnavailablePage do
  use LiveWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
        <main class="container" style="margin: 0 auto; position: relative; width: 100%;">
            <div class="wrapper" style="width: 100%; display: flex; flex-direction: column; padding: 0 20px 20px;">
                <div class="brand" style="padding: 20px 0; display: flex; height: 90px; justify-content: center; align-items: center;">
                    <img id="logo" src={@logo} style="align-self: center; max-width: 100%; height: 100%;" />
                </div>
                <div class="spacer" style="display: flex; width: 100%; height: 80px"></div>
                <div class="content" style="display: grid; place-items: center">
                    <h1
                        class="title"
                        style="
                            margin: 0;
                            font-family: Arial, sans-serif;
                            color: #0000a0;
                            font-size: 27px;
                            font-weight: bold;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            height: 45px;
                        "
                    >
                        Attention
                    </h1>
                    <p
                        class="description"
                        style="
                            font-family: Arial, sans-serif;
                            color: #333333;
                            font-size: 17px;
                            line-height: initial;
                            display: flex;
                            align-items: center;
                            justify-content: center;
                            padding: 3px 5px;
                            min-height: 36px;
                            text-align: center;
                            margin-top: 0;
                        "
                    >
                        The link you are trying to access<br />
                        is no longer available or has expired.
                    </p>
                </div>
            </div>
        </main>
    """
  end
end
