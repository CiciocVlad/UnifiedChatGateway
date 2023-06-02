defmodule Chat.Moment do
  def system_now_ms, do: System.system_time(:millisecond)

  def delay_to_string(time_zone, sec) do
    shifted = Timex.shift(Timex.now(time_zone), seconds: sec)
    DateTime.to_iso8601(DateTime.truncate(shifted, :second))
  end

  def get_time(time_dtz, client_timezone) when time_dtz in [nil, "", []] do
    time = Timex.now(client_timezone)
    [time.hour, time.minute, time.second]
  end

  def get_time(time_dtz, client_timezone) do
    {:ok, received_time} = Timex.parse(time_dtz, "{ISO:Extended}")
    time = Timex.Timezone.convert(received_time, client_timezone)

    [time.hour, time.minute, time.second]
  end
end
