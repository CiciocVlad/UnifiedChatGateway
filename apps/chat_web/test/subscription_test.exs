defmodule ChatWeb.Test.Subscription do
  require Logger
  use ChatWeb.Test.ConnCase

  @transcript_url "http://test/cirrusapi/contactpoints/test/contacts/0000/transcript"

  setup do
    Application.put_env(:plug, :validate_header_keys_during_test, true)
    ChatWeb.TestHelper.ensure_started([:logger, :chat_web, :chat])

    ChatWeb.TestHelper.meck([
      HTTPoison
    ])

    {:ok, %{}}
  end

  test "Create subscription", %{conn: conn} do
    conn = post(conn, "chat/contactpoints/test")

    assert %{"contactid" => contactid} = json_response(conn, 201)

    {:ok, user_process} = Chat.Session.find(contactid)

    assert nil !== contactid
    assert true === Process.alive?(user_process)

    # wait until the process terminate because no request come
    :timer.sleep(6000)
    nil = Chat.Session.find(contactid)
    assert false === Process.alive?(user_process)
  end

  test "Create subscription - missing contactpointid", %{conn: conn} do
    assert %Phoenix.Router.NoRouteError{
             plug_status: 404,
             message: "no route found for POST /chat/contactpoints (ChatWeb.Router)"
           } = catch_error(post(conn, "chat/contactpoints"))
  end

  test "Get subscription", %{conn: conn} do
    # create subscription
    conn = post(conn, "chat/contactpoints/test")

    assert %{"contactid" => contactid} = json_response(conn, 201)
    # get subscription
    conn = get(conn, "chat/contactpoints/test/contacts/" <> contactid <> "/availability")

    assert %{} = json_response(conn, 200)

    {:ok, user_process} = Chat.Session.find(contactid)

    assert nil !== contactid
    assert true === Process.alive?(user_process)

    # get subscription with mismatch contacpointid test0000 vs test
    conn = get(conn, "chat/contactpoints/test0000/contacts/" <> contactid <> "/availability")

    assert %{"errors" => %{"detail" => "Not Found"}} = json_response(conn, 404)

    # wait until the process terminate because no request come
    :timer.sleep(4000)
    conn = get(conn, "chat/contactpoints/test/contacts/" <> contactid <> "/availability")

    assert %{"errors" => %{"detail" => "Not Found"}} = json_response(conn, 404)
    nil = Chat.Session.find(contactid)
    assert false === Process.alive?(user_process)
  end

  test "Get subscription - 404 Not found", %{conn: conn} do
    conn = get(conn, "chat/contactpoints/test/contacts/c0001/availability")

    assert %{"errors" => %{"detail" => "Not Found"}} = json_response(conn, 404)

    nil = Chat.Session.find("c0001")
  end

  @tag :transcript
  test "Get Transcript", %{conn: conn} do
    contactid = "0000"

    :meck.expect(HTTPoison, :get, fn @transcript_url, _headers ->
      {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"input" => "test"})}}
    end)

    {:ok, pid} = Chat.Session.create("test", contactid)
    # get subscription
    conn = get(conn, "chat/contactpoints/test/contacts/" <> contactid <> "/transcript")

    assert %{"input" => "test"} = json_response(conn, 200)

    {:ok, user_process} = Chat.Session.find(contactid)

    assert nil !== contactid
    assert true === Process.alive?(user_process)

    :meck.expect(HTTPoison, :get, fn @transcript_url, _headers ->
      {:ok, %HTTPoison.Response{status_code: 403}}
    end)

    conn = get(conn, "chat/contactpoints/test/contacts/" <> contactid <> "/transcript")

    assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)

    :meck.expect(HTTPoison, :get, fn @transcript_url, _headers ->
      {:ok, %HTTPoison.Error{reason: "unreachable"}}
    end)

    conn = get(conn, "chat/contactpoints/test/contacts/" <> contactid <> "/transcript")

    assert %{"errors" => %{"detail" => "Internal Server Error"}} = json_response(conn, 500)

    # get subscription with mismatch contacpointid test0000 vs test
    conn = get(conn, "chat/contactpoints/test0000/contacts/" <> contactid <> "/transcript")

    assert %{"errors" => %{"detail" => "Not Found"}} = json_response(conn, 404)

    # terminate contact process
    :ok = GenServer.stop(pid)
    conn = get(conn, "chat/contactpoints/test/contacts/" <> contactid <> "/transcript")

    assert %{"errors" => %{"detail" => "Not Found"}} = json_response(conn, 404)
    nil = Chat.Session.find(contactid)
    assert false === Process.alive?(user_process)
  end
end
