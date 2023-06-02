defmodule ChatWeb.FallbackController do
  use ChatWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(ChatWeb.ErrorView)
    |> render(:"404.json")
  end

  def call(conn, {:error, %{status_code: status}}) when is_integer(status) do
    template = :"#{status}.json"

    conn
    |> put_status(status)
    |> put_view(ChatWeb.ErrorView)
    |> render(template)
  end

  def call(conn, _) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(ChatWeb.ErrorView)
    |> render(:"500.json")
  end
end
