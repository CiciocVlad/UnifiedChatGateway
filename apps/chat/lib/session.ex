defmodule Chat.Session do
  alias Chat.{Contact, Cirrus}

  require Logger

  def find(id) do
    case Registry.lookup(Chat.Contact.Registry, id) do
      [{user_process, _}] ->
        {:ok, user_process}

      _ ->
        nil
    end
  end

  ## Visitor Chat API
  def create(contact_point_id, contact_id) do
    case Contact.ProcessSup.start_contact_proc(
           {contact_point_id, contact_id},
           {:via, Registry, {Chat.Contact.Registry, contact_id}}
         ) do
      {:ok, pid} ->
        {:ok, pid}

      # this may not happend because user process does not register name.
      # but maybe it does not hurt if catch and return pid
      {:error, {:already_started, pid}} ->
        {:ok, pid}

      error ->
        Logger.error("failed to start user process #{inspect(error)}")
        :cannot_start_process
    end
  end

  # Msg Apps API
  def create(%{contact_point_id: contact_point_id} = contact_point_data) do
    case Contact.ProcessSup.start_contact_proc(
           contact_point_data,
           {:via, Registry, {Chat.Contact.Registry, contact_point_id}}
         ) do
      {:ok, contact_pid} ->
        {:ok, contact_pid}

      # this may not happend because user process does not register name.
      # but maybe it does not hurt if catch and return pid
      {:error, {:already_started, contact_pid}} ->
        {:ok, contact_pid}

      error ->
        Logger.error("failed to start user process #{inspect(error)}")
        :cannot_start_process
    end
  end

  # Msg Apps API
  def start(contact_point_data) do
    case Cirrus.Socket.connect(contact_point_data) do
      {:ok, socket_pid} ->
        {:ok, socket_pid}

      error ->
        Logger.error("failed to start chat session, error #{inspect(error)}")
        :error
    end
  end

  ## Visitor Chat API
  def start(contact_id, cid) do
    case find(contact_id) do
      {:ok, contact_process} ->
        with {contact_pointid, transactionid} <- Contact.Process.contact_info(contact_process),
             {:ok, _cirrus_process} =
               Cirrus.Socket.connect(contact_pointid, contact_id, transactionid, cid) do
          {:ok, contact_process}
        else
          notfound ->
            Logger.error(
              "Couldn't start chat session of #{inspect(contact_id)} due to error #{inspect(notfound)}"
            )

            {:error, :cannot_start_chat_session}
        end

      _notfound ->
        Logger.error(
          "Couldn't start chat session of #{inspect(contact_id)} due to non-existing contact process"
        )

        {:error, :cannot_start_chat_session}
    end
  end

  def delete(pid) do
    Contact.Process.stop(pid)
  end

  def proc_info(contact_id) do
    case find(contact_id) do
      {:ok, pid} -> {:ok, Contact.Process.contact_info(pid)}
      _notfound -> :undefined
    end
  end

  def get_cirrus_base_url(contact_id) do
    case find(contact_id) do
      {:ok, pid} ->
        Contact.Process.get_cirrus_base_url(pid)

      _notfound ->
        {:error, :not_found}
    end
  end

  def get_contact_point(contact_point_id) do
    case find(contact_point_id) do
      {:ok, pid} ->
        Contact.Process.get_contact_point(pid)

      _notfound ->
        {:error, :not_found}
    end
  end

  def update_cirrus_pid(contact_pid, cirrus_pid) do
    Contact.Process.update_cirrus_pid(contact_pid, cirrus_pid)
  end
end
