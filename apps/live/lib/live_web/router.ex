defmodule LiveWeb.Router do
  use LiveWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LiveWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  ## Visitor Chat API
  scope "/chat/contactpoints", ChatWeb do
    pipe_through :api
    get "/:contactpointid/contacts/:contactid/availability", SubscriptionController, :find
    get "/:contactpointid/availability", SubscriptionController, :availability
    get "/:contactpointid/configuration", SubscriptionController, :configuration
    get "/:contactpointid/contacts/:contactid/transcript", SubscriptionController, :get_transcript
    post "/:contactpointid", SubscriptionController, :create

    get "/:contactpointid/contacts/:contactid/chat-contents/:contentid",
        ContentController,
        :download

    post "/:contactpointid/contacts/:contactid/chat-contents", ContentController, :upload

    post "/:contactpointid/contacts/:contactid/tenants/:tenantid/chat-contents/:fileid",
         ContentController,
         :upload_file
  end

  scope "/chatStatus", LiveWeb do
    pipe_through :api
    get "/:tenantid/:contactPointid", DataAccessController, :availability
  end

  scope "/content", LiveWeb do
    pipe_through :api
    get "/:tenantid/:attachmentid", DataAccessController, :get_content
  end

  scope "/", LiveWeb do
    pipe_through :browser

    live "/chat", Live.Chat
    live "/chat/:tenantid/:contactPointid", Live.Chat
    live "/link", Live.Chat
    live "/link/:tenantid/:contactPointid", Live.Form
    live "/live/:tenantid/:runtimeContactPointid", Live.Form
    live "/", DefaultController
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LiveWeb.Telemetry
    end
  end
end
