defmodule LiveWeb.DataAccessController do
  use LiveWeb, :controller

  alias Chat.{
    Cirrus.Service,
    RateControl
  }

  alias ChatDb.Database

  require Logger

  def availability(conn, param), do: call_cirrus_api(conn, param, "availability")

  def get_content(conn, %{"tenantid" => tenant_id, "attachmentid" => attachment_id} = param) do
    Logger.debug("received get content request #{inspect(param)}")
    %Plug.Conn{remote_ip: ip_address} = conn

    case RateControl.check_rate("attachment", ip_address) do
      :allow ->
        case Database.get_content(tenant_id, attachment_id) do
          {:ok, content} ->
            content = Base.decode64!(content)
            conn = Plug.Conn.put_resp_header(conn, "content-type", "application/octet-stream")
            send_resp(conn, 200, content)

          {:error, :invalid_document_format} ->
            Logger.error(
              "failed to get content, unsupported document (#{tenant_id}, #{attachment_id})"
            )

            send_resp(conn, 500, "Invalid Resource")

          {:error, reason} ->
            Logger.error(
              "error while get content (#{tenant_id}, #{attachment_id}), reason #{inspect(reason)}"
            )

            send_resp(conn, 404, "Not Found")
        end

      :deny ->
        Logger.log(
          :info,
          "rate limit exceeded, denying get content request from #{inspect ip_address}"
        )

        send_resp(conn, 429, "Too many requests")
    end
  rescue
    error ->
      Logger.error(
        "failed to get content, unsupported document (#{tenant_id}, #{attachment_id}), error: #{inspect(error)}"
      )

      send_resp(conn, 500, "Invalid Resource")
  end

  # For Msg Apps /chatStatus endpoint
  defp call_cirrus_api(
         conn,
         %{"tenantid" => tenant_id, "contactPointid" => contact_point_id} = param,
         request_type
       ) do
    Logger.debug("received #{request_type} request #{inspect(param)}")
    %Plug.Conn{remote_ip: ip_address} = conn

    case RateControl.check_rate(request_type, ip_address) do
      :allow ->
        case Service.call_cirrus_api(tenant_id, contact_point_id, request_type) do
          {:ok, _status, body} ->
            put_status(conn, :ok)
            json(conn, body)

          {:error, reason} ->
            Logger.error(
              "error while get contact point (#{tenant_id}, #{contact_point_id}), reason #{inspect(reason)}"
            )
            send_resp(conn, 404, "Not Found")
        end

      :deny ->
        Logger.log(
          :info,
          "rate limit exceeded, denying check #{request_type} request from #{inspect ip_address}"
        )

        send_resp(conn, 429, "Too many requests")
    end
  end
end
