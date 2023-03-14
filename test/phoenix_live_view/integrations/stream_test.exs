defmodule Phoenix.LiveView.StreamTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{StreamLive, DOM, Endpoint}

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{})}
  end

  test "stream is pruned after render", %{conn: conn} do
    {:ok, lv, html} = live(conn, "/stream")

    users = [{"users-1", "chris"}, {"users-2", "callan"}]

    for {id, name} <- users do
      assert html =~ ~s|id="#{id}"|
      assert html =~ name
    end

    stream = StreamLive.run(lv, fn socket -> {:reply, socket.assigns.streams.users, socket} end)

    assert stream.inserts == []
    assert stream.deletes == []

    assert lv |> render() |> users_in_dom("users") == [
             {"users-1", "chris"},
             {"users-2", "callan"}
           ]

    assert lv
           |> element(~S|#users-1 button[phx-click="update"]|)
           |> render_click()
           |> users_in_dom("users") ==
             [{"users-1", "updated"}, {"users-2", "callan"}]

    assert_pruned_stream(lv)

    assert lv
           |> element(~S|#users-2 button[phx-click="move-to-first"]|)
           |> render_click()
           |> users_in_dom("users") ==
             [{"users-2", "updated"}, {"users-1", "updated"}]

    assert lv
           |> element(~S|#users-2 button[phx-click="move-to-last"]|)
           |> render_click()
           |> users_in_dom("users") ==
             [{"users-1", "updated"}, {"users-2", "updated"}]

    assert lv
           |> element(~S|#users-1 button[phx-click="delete"]|)
           |> render_click()
           |> users_in_dom("users") ==
             [{"users-2", "updated"}]

    assert_pruned_stream(lv)

    # second stream in LiveView
    assert lv |> render() |> users_in_dom("admins") == [
             {"admins-1", "chris-admin"},
             {"admins-2", "callan-admin"}
           ]

    assert lv
           |> element(~S|#admins-1 button[phx-click="admin-update"]|)
           |> render_click()
           |> users_in_dom("admins") ==
             [{"admins-1", "updated"}, {"admins-2", "callan-admin"}]

    assert_pruned_stream(lv)

    assert lv
           |> element(~S|#admins-2 button[phx-click="admin-move-to-first"]|)
           |> render_click()
           |> users_in_dom("admins") ==
             [{"admins-2", "updated"}, {"admins-1", "updated"}]

    assert lv
           |> element(~S|#admins-2 button[phx-click="admin-move-to-last"]|)
           |> render_click()
           |> users_in_dom("admins") ==
             [{"admins-1", "updated"}, {"admins-2", "updated"}]

    assert lv
           |> element(~S|#admins-1 button[phx-click="admin-delete"]|)
           |> render_click()
           |> users_in_dom("admins") ==
             [{"admins-2", "updated"}]
  end

  describe "within live component" do
    test "stream operations", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream")

      assert lv |> render() |> users_in_dom("c_users") == [
               {"c_users-1", "chris"},
               {"c_users-2", "callan"}
             ]

      assert lv
             |> element(~S|#c_users-1 button[phx-click="update"]|)
             |> render_click()
             |> users_in_dom("c_users") ==
               [{"c_users-1", "updated"}, {"c_users-2", "callan"}]

      assert_pruned_stream(lv)

      assert lv
             |> element(~S|#c_users-2 button[phx-click="move-to-first"]|)
             |> render_click()
             |> users_in_dom("c_users") ==
               [{"c_users-2", "updated"}, {"c_users-1", "updated"}]

      assert lv
             |> element(~S|#c_users-2 button[phx-click="move-to-last"]|)
             |> render_click()
             |> users_in_dom("c_users") ==
               [{"c_users-1", "updated"}, {"c_users-2", "updated"}]

      assert lv
             |> element(~S|#c_users-1 button[phx-click="delete"]|)
             |> render_click()
             |> users_in_dom("c_users") ==
               [{"c_users-2", "updated"}]

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.StreamComponent,
        id: "stream-component",
        send_assigns_to: self()
      )

      assert_receive {:assigns, %{streams: streams}}
      assert streams.c_users.inserts == []
      assert streams.c_users.deletes == []
      assert_pruned_stream(lv)
    end
  end

  defp assert_pruned_stream(lv) do
    stream = StreamLive.run(lv, fn socket -> {:reply, socket.assigns.streams.users, socket} end)
    assert stream.inserts == []
    assert stream.deletes == []
  end

  defp users_in_dom(html, parent_id) do
    html
    |> DOM.parse()
    |> DOM.all("##{parent_id} > *")
    |> Enum.map(fn {_tag, [{"id", id}], [text | _children]} ->
      {id, String.trim(text)}
    end)
  end
end