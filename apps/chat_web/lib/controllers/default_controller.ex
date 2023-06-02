defmodule ChatWeb.DefaultController do
  use ChatWeb, :controller

  require Logger

  def index(conn, params) do
    Logger.error("connection #{inspect conn} params #{inspect params}")
    json(conn, %{error: "404", error_description: "Not Found"})
  end
end
