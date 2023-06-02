defmodule Chat.Subscription do
  alias Chat.Contact

  require Logger

  def subscribe(contact_pid, type, transport, cirrus_base_url \\ nil) do
    Contact.Process.subscribe(contact_pid, self(), type, transport, cirrus_base_url)
  end

  # Maybe broadcast with contactid instead of contact processid.
  # But this may cause Registry lookup to process eachtime broadcast
  # => Temporarily keep contact pid
  def broadcast(contact_pid, message) do
    Contact.Process.broadcast(contact_pid, self(), message)
  end

  def update_system_socket(contact_pid, socket_pid) do
    Contact.Process.update_system_socket(contact_pid, socket_pid)
  end

  def send_to_system(contact_pid, message) do
    Contact.Process.send_to_system(contact_pid, message)
  end

  def send_to_users(contact_pid, message) do
    Contact.Process.send_to_users(contact_pid, message)
  end
end
