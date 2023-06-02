defmodule LiveWeb.CustomForm do
  alias ChatDb.Database
  alias Chat.{Table, Cirrus.Service}

  require Logger

  def get_form(tenant_id, contact_point_id, form_id) do
    case Table.get(contact_point_id, form_id) do
      [{_, form}] ->
        {:ok, form}

      error ->
        Logger.debug("display form #{form_id} not found in table: #{inspect(error)}")

        case Database.get_form(tenant_id, form_id) do
          %{"formid" => form_id, "code" => form} ->
            Table.save(contact_point_id, form_id, form)
            {:ok, form}

          error ->
            Logger.error("display form #{form_id} not found, error: #{inspect(error)}")

            case Service.get_missing_page(tenant_id, contact_point_id) do
              {:ok, form_id} when form_id not in ["systemMissing", nil] ->
                case Database.get_form(tenant_id, form_id) do
                  %{"formid" => form_id, "code" => form} ->
                    Table.save(contact_point_id, form_id, form)
                    {:ok, form}

                  _ ->
                    nil
                end

              _ ->
                nil
            end
        end
    end
  end
end
