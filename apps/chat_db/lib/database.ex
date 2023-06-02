defmodule ChatDb.Database do
  require Logger

  @config_pool :config
  @default_time_zone "Australia/Melbourne"

  def get_chat_configuration(tenant_id, contact_point_id) do
    key = "tenant::#{tenant_id}::chatConfiguration::#{contact_point_id}"
    pool = get_pool("chatConfiguration", @config_pool)
    get_document(pool, key)
  end

  def get_contact_point(tenant_id, contact_point_id) do
    key = "tenant::#{tenant_id}::contactPoint::#{contact_point_id}"
    pool = get_pool("contactPoint", @config_pool)
    get_document(pool, key)
  end

  def set_contact_point(tenant_id, contact_point_id, expiry, doc) do
    key = "tenant::#{tenant_id}::contactPoint::#{contact_point_id}"
    pool = get_pool("contactPoint", @config_pool)
    set_document(pool, key, expiry, doc)
  end

  def delete_contact_point(tenant_id, contact_point_id) do
    key = "tenant::#{tenant_id}::contactPoint::#{contact_point_id}"
    pool = get_pool("contactPoint", @config_pool)
    :cberl.remove(pool, key)
  end

  def get_tenant(tenant_id) do
    key = "tenant::#{tenant_id}"
    pool = get_pool("tenant", @config_pool)
    get_document(pool, key)
  end

  def get_cluster(cluster_id) do
    key = "system::cluster::#{cluster_id}"
    pool = get_pool("cluster", @config_pool)
    get_document(pool, key)
  end

  def get_default_timezone(tenant_id) do
    key = "tenant::#{tenant_id}::defaultTimeZone"
    pool = get_pool("defaultTimeZone", @config_pool)

    case get_document(pool, key) do
      {:error, _} ->
        @default_time_zone

      value ->
        value
    end
  end

  def get_form(tenant_id, form_id) do
    key = "tenant::#{tenant_id}::form::#{form_id}"
    pool = get_pool("form", @config_pool)
    get_document(pool, key)
  end

  def get_start_page(tenant_id, script_id) do
    key = "tenant::#{tenant_id}::script::#{script_id}::startPage"
    pool = get_pool("form", @config_pool)
    get_document(pool, key)
  end

  def get_start_page(tenant_id) do
    get_form(tenant_id, "startPage")
  end

  def get_end_page(tenant_id) do
    get_form(tenant_id, "endPage")
  end

  def get_expired_page(tenant_id) do
    get_form(tenant_id, "expired")
  end

  def get_missing_page(tenant_id) do
    get_form(tenant_id, "missingPage")
  end

  def get_landing_page(tenant_id) do
    get_form(tenant_id, "landingPage")
  end

  def get_content(tenant_id, attachment_id) do
    key = "tenant::#{tenant_id}::attach::#{attachment_id}::1"
    pool = get_pool("attachment", @config_pool)

    case get_document(pool, key) do
      %{"type" => "attach", "access" => "public", "content" => content} = doc ->
        case Map.get(doc, "maxIndex") do
          nil ->
            get_next_content(tenant_id, attachment_id, 2, content)

          1 ->
            {:ok, content}

          max_index ->
            get_next_content(tenant_id, attachment_id, 2, max_index, content)
        end

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :invalid_document_format}
    end
  end

  defp get_next_content(tenant_id, attachment_id, index, total_content) do
    key = "tenant::#{tenant_id}::attach::#{attachment_id}::#{index}"
    pool = get_pool("attachment", @config_pool)

    case get_document(pool, key) do
      %{"type" => "attach", "access" => "public", "content" => content} ->
        get_next_content(tenant_id, attachment_id, index + 1, total_content <> content)

      {:error, :not_found} ->
        {:ok, total_content}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :invalid_document_format}
    end
  end

  defp get_next_content(tenant_id, attachment_id, index, max_index, total_content)
       when index <= max_index do
    key = "tenant::#{tenant_id}::attach::#{attachment_id}::#{index}"
    pool = get_pool("attachment", @config_pool)

    case get_document(pool, key) do
      %{"type" => "attach", "access" => "public", "content" => content} ->
        get_next_content(tenant_id, attachment_id, index + 1, max_index, total_content <> content)

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :invalid_document_format}
    end
  end

  defp get_next_content(_tenant_id, _attachment_id, _index, _max_index, total_content) do
    {:ok, total_content}
  end

  def get_document(pool, key) do
    case :cberl.get(pool, key) do
      {_, _, doc} ->
        deserialize(doc)

      {_, {:error, :key_enoent}} ->
        {:error, :not_found}

      {_, error} ->
        {:error, error}

      error ->
        {:error, error}
    end
  end

  def set_document(pool, key, expiry, doc) do
    case :cberl.set(pool, key, expiry, doc) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, reason}

      reason ->
        {:error, reason}
    end
  end

  defp get_pool(doc_type, default_pool) do
    bucket_config = Application.get_env(:chat_db, :bucket_config, [])

    case List.keyfind(bucket_config, doc_type, 0) do
      nil ->
        default_pool

      {_, pool} ->
        pool
    end
  end

  defp deserialize(%{"type" => "tenantDefaultTimeZone"} = doc) do
    default_time_zone = Map.get(doc, "defaultTimeZone", %{})
    Map.get(default_time_zone, "IANATZID", @default_time_zone)
  end

  defp deserialize(doc) do
    doc
  end
end
