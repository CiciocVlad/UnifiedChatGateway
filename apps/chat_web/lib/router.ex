defmodule ChatWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug
    plug Plug.Logger
    plug Plug.Parsers, parsers: [:json, :multipart], json_decoder: Jason
  end

  # scope "/chat/contactpoints", ChatWeb do
  #   pipe_through :api
  #   get "/:contactpointid/contacts/:contactid/availability", SubscriptionController, :find
  #   get "/:contactpointid/availability", SubscriptionController, :availability
  #   get "/:contactpointid/configuration", SubscriptionController, :configuration
  #   get "/:contactpointid/contacts/:contactid/transcript", SubscriptionController, :get_transcript
  #   post "/:contactpointid", SubscriptionController, :create

  #   get "/:contactpointid/contacts/:contactid/chat-contents/:contentid",
  #       ContentController,
  #       :download

  #   post "/:contactpointid/contacts/:contactid/chat-contents", ContentController, :upload
  # end

  # scope "/", ChatWeb do
    # pipe_through :api
    # get "/", DefaultController, :index
  # end
end
