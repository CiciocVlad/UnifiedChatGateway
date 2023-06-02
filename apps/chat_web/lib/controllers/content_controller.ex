defmodule ChatWeb.ContentController do
  use ChatWeb, :controller

  alias Chat.{
    RateControl,
    Cirrus.Service
  }

  require Logger

  action_fallback ChatWeb.FallbackController

  def download(%Plug.Conn{} = conn, %{
        "contactpointid" => contact_point_id,
        "contactid" => contact_id,
        "contentid" => content_id
      }) do
    # set_logger_metadata(tenant, username, thread_id)
    Logger.info("received a chat content download request for #{inspect content_id}")
    %Plug.Conn{remote_ip: ip_address} = conn

    case RateControl.check_rate(:download_content, ip_address) do
      :allow ->
        case Service.download_file(contact_point_id, contact_id, content_id) do
          {:ok, _status, response_body} ->
            conn = Plug.Conn.put_resp_header(conn, "content-type", "application/octet-stream")
            send_resp(conn, 200, response_body)

          {:error, Reason} ->
            {:error, Reason}
        end

      :deny ->
        Logger.log(
          :info,
          "rate limit exceeded, denying download request from #{inspect ip_address}"
        )

        conn |> send_resp(429, "Too many requests")
    end
  end

  # Visitor Chat API
  def upload(
        %Plug.Conn{} = conn,
        %{
          "contactpointid" => contact_point_id,
          "contactid" => contact_id,
          "filename" => %Plug.Upload{filename: filename, path: path}
        }
      ) do
    # set_logger_metadata(tenant, username, thread_id)

    Logger.info(
      "received chat content upload request with filename #{inspect(filename)}, path: #{
        inspect path
      }"
    )

    %Plug.Conn{remote_ip: ip_address} = conn

    case RateControl.check_rate(:upload_content, ip_address) do
      :allow ->
        case Service.upload_file(contact_point_id, contact_id, path, filename) do
          {:ok, _status, response_body} ->
            put_status(conn, :ok)
            json(conn, response_body)

          {:error, Reason} ->
            {:error, Reason}
        end

      :deny ->
        Logger.log(
          :info,
          "rate limit exceeded, denying upload request from #{inspect ip_address}"
        )

        conn |> send_resp(429, "Too many requests")
    end
  end

  # Msg App API
  def upload_file(conn, %{
    "tenantid" => tenant_id,
    "contactpointid" => contact_point_id,
    "contactid" => contact_id,
    "fileid" => file_id,
    "file" => file,
  }) do
    %Plug.Conn{remote_ip: ip_address} = conn

    filename = "#{file_id}.jpg"
    path = Path.join([:code.priv_dir(:live), "static", "uploads", filename])

    File.write!(path, file |> String.replace(~r/.*base64,/, "") |> Base.decode64!(), ~w(binary)a)

    case RateControl.check_rate(:upload_content, ip_address) do
      :allow ->
        case Service.upload_file(tenant_id, contact_point_id, contact_id, path, file_id, filename) do
          {:ok, _status, response_body} ->
            put_status(conn, :ok)
            json(conn, response_body)

          {:error, reason} ->
            {:error, reason}
        end

      :deny ->
        Logger.log(
          :info,
          "rate limit exceeded, denying upload request from #{inspect ip_address}"
        )

        conn |> send_resp(429, "Too many requests")
    end
  end
end
