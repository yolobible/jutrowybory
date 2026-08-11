defmodule JutrowyboryWeb.PageControllerTest do
  use JutrowyboryWeb.ConnCase

  import Jutrowybory.AccountsFixtures

  test "GET / renderuje landing page dla gościa", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "JutroWybory"
    assert html =~ "Zarejestruj się"
    assert html =~ "Zaloguj się"
    assert html =~ "Jak to działa?"
  end

  test "GET / dla zalogowanego pokazuje link do ankiety", %{conn: conn} do
    conn =
      conn
      |> log_in_user(user_fixture())
      |> get(~p"/")

    html = html_response(conn, 200)
    assert html =~ "Przejdź do ankiety"
    refute html =~ "Zarejestruj się"
  end
end
