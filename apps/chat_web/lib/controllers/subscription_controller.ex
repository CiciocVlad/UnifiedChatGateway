defmodule ChatWeb.SubscriptionController do
  use ChatWeb, :controller

  alias Chat.{
    Guid,
    Session,
    Cirrus.Service,
    RateControl
  }

  require Logger

  action_fallback ChatWeb.FallbackController

  def create(conn, %{"contactpointid" => contact_point_id} = param) do
    Logger.debug("received create subscription request #{inspect(param)}")
    %Plug.Conn{remote_ip: ip_address} = conn

    case RateControl.check_rate(:create_subscription, ip_address) do
      :allow ->
        with contactid = Guid.new(),
             {:ok, pid} <- Session.create(contact_point_id, contactid),
             true <- is_pid(pid) do
          conn
          |> put_status(:created)
          |> render("show.json", subscription: %{id: contactid})
        end

      :deny ->
        Logger.log(
          :info,
          "rate limit exceeded, denying subscription request from #{inspect ip_address}"
        )

        conn |> send_resp(429, "Too many requests")
    end
  end

  def find(conn, %{"contactpointid" => contact_point_id, "contactid" => contact_id} = param) do
    Logger.debug("received GET subscription request #{inspect(param)}")
    %Plug.Conn{remote_ip: ip_address} = conn

    case RateControl.check_rate(:check_contact_availability, ip_address) do
      :allow ->
        with {:ok, _transid} <- Service.check_contact_available(contact_point_id, contact_id) do
          conn
          |> put_status(:ok)
          |> render("subscription.json", [])
        end

      :deny ->
        Logger.log(
          :info,
          "rate limit exceeded, denying check contact available request from #{inspect ip_address}"
        )

        conn |> send_resp(429, "Too many requests")
    end
  end

  def availability(conn, param), do: call_cirrus_api(conn, param, "availability")

  def configuration(conn, param), do: call_cirrus_api(conn, param, "configuration")

  def get_transcript(
        conn,
        %{"contactpointid" => contact_point_id, "contactid" => contact_id} = param
      ) do
    Logger.debug("received GET transcript request #{inspect(param)}")
    %Plug.Conn{remote_ip: ip_address} = conn

    case RateControl.check_rate(:get_transcript, ip_address) do
      :allow ->
        case Service.get_transcript(contact_point_id, contact_id) do
          {:ok, _status, transcript} ->
            conn
            |> put_status(:ok)
            |> render("transcript.json", transcript: transcript)

          {:error, reason} ->
            {:error, reason}
        end

      :deny ->
        Logger.log(
          :info,
          "rate limit exceeded, denying get transcript request from #{inspect ip_address}"
        )

        conn |> send_resp(429, "Too many requests")
    end
  end

  defp call_cirrus_api(conn, %{"contactpointid" => contact_point_id} = param, request_type) do
    Logger.debug("received #{request_type} request #{inspect(param)}")
    %Plug.Conn{remote_ip: ip_address} = conn

    case RateControl.check_rate(request_type, ip_address) do
      :allow ->
        case Service.call_cirrus_api(contact_point_id, request_type) do
          {:ok, _status, body} ->
            put_status(conn, :ok)
            json(conn, body)

          {:error, reason} ->
            {:error, reason}
        end

      :deny ->
        Logger.log(
          :info,
          "rate limit exceeded, denying check #{request_type} request from #{inspect ip_address}"
        )

        conn |> send_resp(429, "Too many requests")
    end
  end

  # For Msg Apps /chatStatus endpoint
  defp call_cirrus_api(conn, %{"tenantid" => tenantid, "contactPointid" => contact_point_id} = param, request_type) do
    Logger.debug("received #{request_type} request #{inspect(param)}")
    %Plug.Conn{remote_ip: ip_address} = conn

    case RateControl.check_rate(request_type, ip_address) do
      :allow ->
        case Service.call_cirrus_api(tenantid, contact_point_id, request_type) do
          {:ok, _status, body} ->
            put_status(conn, :ok)
            json(conn, body)

          {:error, reason} ->
            {:error, reason}
        end

      :deny ->
        Logger.log(
          :info,
          "rate limit exceeded, denying check #{request_type} request from #{inspect ip_address}"
        )

        conn |> send_resp(429, "Too many requests")
    end
  end
end
