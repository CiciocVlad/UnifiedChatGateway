defmodule Chat.Cirrus.Service do
  require Logger

  alias Chat.{Guid, Session, Table}
  alias ChatDb.Database

  defguard valid_form?(form_id, form) when form_id not in [nil, ""] and form not in [nil, ""]

  def get_transcript(tenant_id, contact_point_id, contact_id) do
    url = "/cirrusapi/#{tenant_id}/#{contact_point_id}/contacts/#{contact_id}/transcript"

    do_get(url, [], tenant_id, contact_point_id, contact_id)
  end

  ## Visitor Chat API
  def get_transcript(contact_point_id, contact_id) do
    url =
      "/cirrusapi/contactpoints/" <>
        contact_point_id <> "/contacts/" <> contact_id <> "/transcript"

    do_get1(url, [], contact_point_id, nil)
  end

  ## Visitor Chat API
  def call_cirrus_api(contact_point_id, request_type) do
    url = "/cirrusapi/contactpoints/" <> contact_point_id <> "/" <> request_type
    do_get1(url, [], contact_point_id)
  end

  # Msg Apps API
  def call_cirrus_api(tenant_id, contact_point_id, request_type) do
    url = "/cirrusapi/#{tenant_id}/#{contact_point_id}/#{request_type}"
    do_get(url, [], tenant_id, contact_point_id)
  end

  # Msg Apps API with base URL
  def call_cirrus_api(tenant_id, contact_point_id, cirrus_api_base_url, request_type) do
    url = "/cirrusapi/#{tenant_id}/#{contact_point_id}/#{request_type}"
    do_get!("http://" <> cirrus_api_base_url <> url, [])
  end

  # Visitor Chat API
  def upload_file(contact_point_id, contact_id, path, filename) do
    case get_cirrus_api_base_url(contact_point_id, contact_id) do
      {:ok, cirrus_api_base_url} ->
        do_upload(filename, path, cirrus_api_base_url)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Msg Apps API
  def upload_file_with_content(tenant_id, contact_point_id, contact_id, content, file_id, filename) do
    case get_cirrus_api_base_url(tenant_id, contact_point_id, contact_id) do
      {:ok, cirrus_api_base_url} ->
        do_upload_with_content(file_id, filename, content, tenant_id, cirrus_api_base_url)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def upload_file(tenant_id, contact_point_id, contact_id, path, file_id, filename) do
    case get_cirrus_api_base_url(tenant_id, contact_point_id, contact_id) do
      {:ok, cirrus_api_base_url} ->
        do_upload(file_id, filename, path, tenant_id, cirrus_api_base_url)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Visitor Chat API
  def download_file(contact_point_id, contact_id, content_id) do
    case get_cirrus_api_base_url(contact_point_id, contact_id) do
      {:ok, cirrus_api_base_url} ->
        do_download(cirrus_api_base_url, content_id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Msg Apps API
  def download_file(tenant_id, contact_point_id, contact_id, content_id) do
    case get_cirrus_api_base_url(tenant_id, contact_point_id, contact_id) do
      {:ok, cirrus_api_base_url} ->
        do_download(tenant_id, cirrus_api_base_url, content_id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Visitor Chat API
  def do_get1(url, headers, contact_point_id, contact_id \\ nil) do
    case get_cirrus_api_base_url(contact_point_id, contact_id) do
      {:ok, cirrus_api_base_url} ->
        do_get!("http://" <> cirrus_api_base_url <> url, headers)

      {:error, reason} ->
        Logger.error(
          "#{url} request failure, reason: error while getting cirrus_api_base_url #{inspect(reason)}"
        )

        {:error, :internal_error}
    end
  catch
    class, exception ->
      stacktrace = __STACKTRACE__
      Logger.error("#{Exception.format(class, exception, stacktrace)}")
      {:error, :internal_error}
  end

  # Msg Apps API
  def do_get(url, headers, tenant_id, contact_point_id, contact_id \\ nil) do
    case get_cirrus_api_base_url(tenant_id, contact_point_id, contact_id) do
      {:ok, cirrus_api_base_url} ->
        do_get!("http://" <> cirrus_api_base_url <> url, headers)

      {:error, :contact_point_not_found} ->
        {:error, :contact_point_not_found}

      _ ->
        {:error, :internal_error}
    end
  catch
    class, exception ->
      stacktrace = __STACKTRACE__
      Logger.error("#{Exception.format(class, exception, stacktrace)}")
      {:error, :internal_error}
  end

  def do_get!(url, headers) do
    Logger.debug("send GET request to url #{url}")

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}}
      when status in [200, 204, 404] ->
        Logger.info("request to #{url} received status: #{status}")
        {:ok, status, decode(body, body)}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.error("request to #{url} received status: #{status}")
        {:error, %{status_code: status}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("request to #{url} failed. reason #{inspect(reason)}")
        {:error, reason}
    end
  end

  def decode(data, default \\ nil)
  def decode(data, default) when data in [nil, "", []], do: default

  def decode(data, default) do
    Jason.decode!(data)
  catch
    _, error ->
      Logger.error("failed to decode data #{inspect(data)} due to error #{inspect(error)}")

      default
  end

  ## Visitor Chat API
  def get_cirrus_api_base_url(_contact_point_id, nil) do
    case Application.get_env(:chat, :cirrus_base_urls) do
      cirrus_base_urls when cirrus_base_urls in [nil, []] ->
        {:error, :undefined_cirrus_base_urls}

      cirrus_base_urls ->
        [cirrus_base_url | _] = Enum.shuffle(cirrus_base_urls)
        {:ok, cirrus_base_url}
    end
  end

  ## Visitor Chat API
  def get_cirrus_api_base_url(contact_point_id, contact_id) do
    with {:ok, _transid} <- check_contact_available(contact_point_id, contact_id),
         {:ok, cirrus_base_url} <- Session.get_cirrus_base_url(contact_id) do
      {:ok, cirrus_base_url}
    else
      error ->
        Logger.error("get_cirrus_api_base_url error #{inspect(error)}")
        {:error, error}
    end
  end

  # Msg Apps API
  def get_cirrus_api_base_url(tenant_id, contact_point_id, contact_id) do
    with {:ok, %{cirrus_base_url: cirrus_base_url}} <-
           get_contact_point(tenant_id, contact_point_id) do
      {:ok, cirrus_base_url}
    else
      {:error, :contact_point_not_found} ->
        {:error, :contact_point_not_found}

      error ->
        Logger.error(
          "error getting base URL for contactPoint: #{contact_point_id}, contactid: #{contact_id}, error: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  ## Visitor Chat API
  def check_contact_available(contact_point_id, contact_id) do
    case Session.proc_info(contact_id) do
      {:ok, {^contact_point_id, transid}} ->
        {:ok, transid}

      {:ok, {mismatch_contact_point_id, _transid}} ->
        Logger.error(
          "contact process's contact info #{inspect(mismatch_contact_point_id)} does not match with request #{contact_point_id}"
        )

        {:error, :not_found}

      _notfound ->
        Logger.error("contact process of #{contact_point_id} does not exist")
        {:error, :not_found}
    end
  end

  # Msg Apps API
  def get_contact_point(tenant_id, contact_point_id) do
    doc = Database.get_contact_point(tenant_id, contact_point_id)
    format_contact_point_data(tenant_id, contact_point_id, doc)
  end

  def set_runtime_contact_point(tenant_id, contact_point_id, src_contact_point_id) do
    doc = %{
      "type" => "contactPoint",
      "tenantid" => tenant_id,
      "contactPointid" => contact_point_id,
      "initType" => "tempRuntime",
      "sourceContactPointid" => src_contact_point_id
    }

    case Database.set_contact_point(tenant_id, contact_point_id, 3 * 60, doc) do
      :ok ->
        Logger.info("temporary runtime contact point #{contact_point_id} document created")
        :ok

      error ->
        Logger.error(
          "temporary runtime contact point #{contact_point_id} document create error: #{inspect(error)}"
        )

        :error
    end
  end

  def get_start_page(%{
                        tenant_id: tenant_id,
                        contact_point_id: contact_point_id,
                        script_id: script_id
                      }) when script_id not in [nil, ""] do
    case Database.get_start_page(tenant_id, script_id) do
      %{"formid" => form_id} when form_id not in [nil, ""] ->
        {:ok, form_id}

      error ->
        Logger.error("start page not found in script: #{script_id}, error: #{inspect(error)}")
        get_tenant_start_page(tenant_id, contact_point_id)
    end
  end

  def get_start_page(%{
                        tenant_id: tenant_id,
                        contact_point_id: contact_point_id
                      }) do
    get_start_page(tenant_id, contact_point_id)
  end

  def get_start_page(tenant_id, contact_point_id) do
    case Database.get_contact_point(tenant_id, contact_point_id) do
      %{"scriptid" => script_id} when script_id not in [nil, ""] ->
        case Database.get_start_page(tenant_id, script_id) do
          %{"formid" => form_id} when form_id not in [nil, ""] ->
            {:ok, form_id}

          error ->
            Logger.error("start page not found in script: #{script_id}, error: #{inspect(error)}")
            get_tenant_start_page(tenant_id, contact_point_id)
        end

      error ->
        Logger.error(
          "get start page failed, script id not found in contact point: #{contact_point_id}, error: #{inspect(error)}"
        )

        get_tenant_start_page(tenant_id, contact_point_id)
    end
  end

  def get_tenant_start_page(tenant_id, contact_point_id) do
    case Database.get_start_page(tenant_id) do
      %{"formid" => form_id, "code" => form} when valid_form?(form_id, form) ->
        Table.save(contact_point_id, form_id, form)
        {:ok, form_id}

      error ->
        Logger.info("error getting start page #{inspect(error)}")
        get_system_start_page()
    end
  end

  def get_system_start_page() do
    {:ok, "systemStartPage"}
  end

  def get_end_page(tenant_id, contact_point_id) do
    case Database.get_end_page(tenant_id) do
      %{"formid" => form_id, "code" => form} when valid_form?(form_id, form) ->
        Table.save(contact_point_id, form_id, form)
        {:ok, form_id}

      error ->
        Logger.info("error getting end page #{inspect(error)}")
        get_system_end_page()
    end
  end

  def get_system_end_page() do
    {:ok, "systemEndPage"}
  end

  def get_expired_page(tenant_id, contact_point_id) do
    case Database.get_expired_page(tenant_id) do
      %{"formid" => form_id, "code" => form} when valid_form?(form_id, form) ->
        Table.save(contact_point_id, form_id, form)
        {:ok, form_id}

      error ->
        Logger.info("error getting expired page #{inspect error}")
        get_system_expired_page()
    end
  end

  def get_system_expired_page() do
    {:ok, "systemExpired"}
  end

  def get_missing_page(tenant_id, contact_point_id) do
    case Database.get_missing_page(tenant_id) do
      %{"formid" => form_id, "code" => form} ->
        Table.save(contact_point_id, form_id, form)
        {:ok, form_id}

      error ->
        Logger.info("error getting missing page #{inspect error}")
        get_system_misssing_page()
    end
  end

  def get_system_misssing_page() do
    {:ok, "systemMissing"}
  end

  def get_landing_page(tenant_id, contact_point_id) do
    case Database.get_landing_page(tenant_id) do
      %{"formid" => form_id, "code" => form} ->
        Table.save(contact_point_id, form_id, form)
        {:ok, form_id}

      error ->
        Logger.info("error getting landing page #{inspect error}")
        get_system_landing_page()
    end
  end

  def get_system_landing_page() do
    {:ok, "systemLanding"}
  end

  def may_transit_contact_point(tenant_id, contact_point_id, src_contact_point_id) do
    case Database.get_contact_point(tenant_id, src_contact_point_id) do
      %{
        "initType" => init_type
      }
      when init_type in ["offline", "runtime"] ->
        Logger.debug(
          "ignore transition #{init_type} source contact point #{src_contact_point_id}"
        )

      %{
        "initType" => "online"
      } = doc ->
        expiry_seconds = Application.get_env(:live, :runtime_link_expiry, 60 * 24) * 60

        doc =
          doc
          |> Map.put("initType", "runtime")
          |> Map.put("contactPointid", contact_point_id)
          |> Map.drop([
            "scriptid",
            "scriptName",
            "revisionSuffix",
            "expiry",
            "origin",
            "contactData"
          ])

        case Database.set_contact_point(tenant_id, contact_point_id, expiry_seconds, doc) do
          :ok ->
            Logger.info("runtime contact point #{contact_point_id} made permanent")
            Database.delete_contact_point(tenant_id, src_contact_point_id)
            Logger.info("online source contact point #{src_contact_point_id} deleted")

          error ->
            Logger.error(
              "runtime contact point #{contact_point_id} create error: #{inspect(error)}"
            )
        end

      error ->
        Logger.error("source contact point #{src_contact_point_id} read error: #{inspect(error)}")
    end
  end

  def transit_offline_contact_point(%{
        init_type: "offline",
        tenant_id: tenant_id,
        contact_point_id: contact_point_id,
        contact_id: contact_id,
        transaction_id: transaction_id,
        cirrus_base_url: cirrus_base_url,
        cirrus_pid: cirrus_pid
      }) do
    case Database.get_contact_point(tenant_id, contact_point_id) do
      %{
        "initType" => "tempRuntime"
      } = doc ->
        doc =
          doc
          |> Map.put("initType", "runtime")
          |> Map.put("contactPointid", contact_point_id)
          |> Map.put("contactid", contact_id)
          |> Map.put("transactionid", transaction_id)
          |> Map.put("baseURL", cirrus_base_url)
          |> Map.put("pid", cirrus_pid)
          |> Map.drop(["sourceContactPointid"])

        expiry_seconds = Application.get_env(:live, :runtime_link_expiry, 60 * 24) * 60

        case Database.set_contact_point(tenant_id, contact_point_id, expiry_seconds, doc) do
          :ok ->
            Logger.info("runtime contact point #{contact_point_id} made permanent")

          error ->
            Logger.error(
              "runtime contact point #{contact_point_id} create error: #{inspect(error)}"
            )
        end

      result ->
        Logger.error("get contact point #{contact_point_id} error, result: #{inspect(result)}")
    end
  end

  def transit_offline_contact_point(_), do: :ok

  defp format_contact_point_data(tenant_id, contact_point_id, %{
         "initType" => "offline",
         "status" => "Active",
         "scriptid" => script_id
       }) do
    with %{"homeCluster" => homeCluster} <- Database.get_tenant(tenant_id),
         %{"cirrusURLs" => cirrus_base_urls} <- Database.get_cluster(homeCluster) do
      [cirrus_base_url | _] = Enum.shuffle(cirrus_base_urls)

      data = %{
        init_type: "offline",
        tenant_id: tenant_id,
        contact_id: Guid.new(),
        transaction_id: Guid.new(),
        contact_point_id: contact_point_id,
        script_id: script_id,
        cirrus_base_url: cirrus_base_url
      }

      {:ok, data}
    else
      error ->
        Logger.error(
          "no route found for offline contact (#{tenant_id}, #{contact_point_id}), error: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  defp format_contact_point_data(_tenant_id, _contact_point_id, %{
         "initType" => "tempRuntime",
         "sourceContactPointid" => src_contact_point_id
       }) do
    {:ok, %{src_contact_point_id: src_contact_point_id}}
  end

  defp format_contact_point_data(
         tenant_id,
         contact_point_id,
         %{
           "initType" => init_type,
           "contactid" => contact_id,
           "transactionid" => transaction_id,
           "baseURL" => cirrus_base_url,
           "pid" => cirrus_pid
         } = doc
       ) do
    data = %{
      init_type: init_type,
      tenant_id: tenant_id,
      contact_id: contact_id,
      transaction_id: transaction_id,
      contact_point_id: contact_point_id,
      script_id: Map.get(doc, "scriptid"),
      cirrus_base_url: cirrus_base_url,
      cirrus_pid: cirrus_pid
    }

    {:ok, data}
  end

  defp format_contact_point_data(tenant_id, contact_point_id, {:error, :not_found}) do
    Logger.error("contactPoint (#{tenant_id}, #{contact_point_id}) not_found")
    {:error, :contact_point_not_found}
  end

  defp format_contact_point_data(tenant_id, contact_point_id, doc) do
    Logger.error("contactPoint (#{tenant_id}, #{contact_point_id}) invalid: #{inspect(doc)}")
    {:error, :invalid_contact_point}
  end

  ## Visitor Chat API
  defp do_upload(filename, path, cirrus_api_base_url) do
    {:ok, content} = File.read(path)
    url = "http://" <> cirrus_api_base_url <> "/cirrusapi/chat-content/upload"

    case HTTPoison.post(
           url,
           {:multipart,
            [
              {"file", content,
               {"form-data", [{"name", "\"filename\""}, {"filename", "#{inspect(filename)}"}]},
               []}
            ]}
         ) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        Logger.info("chat content upload request success")
        {:ok, 200, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.error("request to #{url} received status: #{status}")
        {:error, %{status_code: status}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("request to #{url} failed. reason #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error in Error ->
      Logger.error("request to upload file failed. reason #{inspect(error)}")
      {:error, :internal_error}
  end

  # Msg Apps API
  defp do_upload_with_content(file_id, filename, content, tenantid, cirrus_api_base_url) do
    url = "http://" <> cirrus_api_base_url <> "/cirrusapi/tenants/#{tenantid}/attachments"
    case HTTPoison.post(
           url,
           {:multipart,
            [
              {"file", content,
               {"form-data", [{"name", "\"fileName\""}, {"fileName", "#{inspect(filename)}"}]},
               []},
              {"fileid", "#{file_id}"},
              {"ownerType", "transaction"},
              {"ownerGUID", "fqv5ZiRpaUCS1KwMmTLScA"}
            ]}
         ) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        Logger.info("chat content upload request success")
        {:ok, 200, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.error("request to #{url} received status: #{status}")
        {:error, %{status_code: status}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("request to #{url} failed. reason #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error in Error ->
      Logger.error("request to upload file failed. reason #{inspect(error)}")
      {:error, :internal_error}
  end

  defp do_upload(file_id, filename, path, tenantid, cirrus_api_base_url) do
    {:ok, content} = File.read(path)
    url = "http://" <> cirrus_api_base_url <> "/cirrusapi/tenants/#{tenantid}/attachments"

    case HTTPoison.post(
           url,
           {:multipart,
            [
              {"file", content,
               {"form-data", [{"name", "\"fileName\""}, {"fileName", "#{inspect(filename)}"}]},
               []},
              {"fileid", "#{file_id}"},
              {"ownerType", "transaction"},
              {"ownerGUID", "fqv5ZiRpaUCS1KwMmTLScA"}
            ]}
         ) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        Logger.info("chat content upload request success")
        {:ok, 200, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.error("request to #{url} received status: #{status}")
        {:error, %{status_code: status}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("request to #{url} failed. reason #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error in Error ->
      Logger.error("request to upload file failed. reason #{inspect(error)}")
      {:error, :internal_error}
  end

  ## Visitor Chat API
  defp do_download(cirrus_api_base_url, content_id) do
    url =
      "http://" <> cirrus_api_base_url <> "/cirrusapi/chat-content/" <> content_id <> "/download"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        {:ok, 200, body}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.error("request to #{url} received status: #{status}")
        {:error, %{status_code: status}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("request to #{url} failed. reason #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Msg Apps API
  defp do_download(tenant_id, cirrus_api_base_url, content_id) do
    url =
      "http://" <>
        cirrus_api_base_url <> "/cirrusapi/tenants/" <> tenant_id <> "/attachments/" <> content_id

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        {:ok, 200, body}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.error("request to #{url} received status: #{status}")
        {:error, %{status_code: status}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("request to #{url} failed. reason #{inspect(reason)}")
        {:error, reason}
    end
  end
end
