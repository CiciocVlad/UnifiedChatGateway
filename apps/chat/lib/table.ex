defmodule Chat.Table do
  require Logger

  def create(contact_point_id) do
    :ets.new(toa(contact_point_id), [:set, :named_table, {:keypos, 1}, :public])
  rescue
    err ->
      Logger.error("table create error #{inspect(err)}")
  end

  def insert(contact_point_id, form_id, form) do
    :ets.insert(toa(contact_point_id), {form_id, form})
  rescue
    err ->
      Logger.debug("table insert failed #{inspect(err)}")
  end

  def get(contact_point_id, form_id) do
    :ets.lookup(toa(contact_point_id), form_id)
  rescue
    err ->
      Logger.debug("table lookup failed #{inspect(err)}")
      []
  end

  def delete(contact_point_id) do
    :ets.delete(toa(contact_point_id))
  rescue
    err ->
      Logger.error("table delete error #{inspect(err)}")
  end

  def save(contact_point_id, form_id, form) do
    case get(contact_point_id, form_id) do
      [] ->
        insert(contact_point_id, form_id, form)

      _ ->
        :ok
    end
  end

  defp toa(str) do
    String.to_existing_atom(str)
  rescue
    _ ->
      String.to_atom(str)
  end
end
