defmodule Chat.RateControl do
  require Logger

  @default_scale_ms 1_000
  @default_rate_limit 1

  def check_rate(request_type, ip_address) do
    rate_limit = Application.get_env(:chat, :rate_limit, @default_rate_limit)
    scale_ms = Application.get_env(:chat, :rate_limit_scale, @default_scale_ms)

    rate_limit_white_list = Application.get_env(:chat, :rate_limit_white_list, [])
    ip_address = format_ip_address(ip_address)

    case ip_address in rate_limit_white_list do
      true ->
        :allow

      _ ->
        case Hammer.check_rate(
               "#{inspect request_type}:#{inspect ip_address}",
               scale_ms,
               rate_limit
             ) do
          {:allow, _count} ->
            :allow

          {:deny, _limit} ->
            :deny

          error ->
            Logger.error("failed to rate limit, reason: #{inspect error}")
            :allow
        end
    end
  end

  defp format_ip_address(ip_address) when is_tuple(ip_address), do: "#{:inet.ntoa(ip_address)}"
  defp format_ip_address(ip_address), do: ip_address
end
