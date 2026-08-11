defmodule JutrowyboryWeb.AdminStatsControllerTest do
  use JutrowyboryWeb.ConnCase, async: true

  import Jutrowybory.AccountsFixtures

  alias Jutrowybory.Survey

  defp admin_fixture do
    user_fixture()
    |> Ecto.Changeset.change(role: "admin")
    |> Jutrowybory.Repo.update!()
  end

  setup do
    {:ok, topic} = Survey.create_topic(%{name: "Gospodarka"})

    {:ok, question} =
      Survey.create_question(%{text: "podwyższeniem płacy minimalnej", topic_id: topic.id})

    voter = user_fixture()
    {:ok, _} = Survey.upsert_answer(voter, question.id, 3)
    {:ok, _} = Survey.create_comment(voter, question.id, %{"body" => "Popieram"})

    %{question: question}
  end

  test "GET /admin/eksport.json zwraca JSON ze statystykami dla admina", %{conn: conn} do
    conn =
      conn
      |> log_in_user(admin_fixture())
      |> get(~p"/admin/eksport.json")

    assert response_content_type(conn, :json)
    assert get_resp_header(conn, "content-disposition") != []

    data = Jason.decode!(response(conn, 200))

    assert data["globalne"]["answers"] == 1
    assert data["globalne"]["comments"] == 1
    assert data["wygenerowano"]

    assert [question] = data["pytania"]
    assert question["pytanie"] == "Czy zgadzasz się z podwyższeniem płacy minimalnej"
    assert question["temat"] == "Gospodarka"
    assert question["odpowiedzi"] == 1
    assert question["srednia"] == 3.0
    assert question["mediana"] == 3
    assert question["rozklad"] == %{
             "zdecydowanie nie" => 0,
             "raczej nie" => 0,
             "nie wiem" => 0,
             "raczej tak" => 1,
             "zdecydowanie tak" => 0
           }

    assert question["najlepszy_komentarz"]["tresc"] == "Popieram"
  end

  test "GET /admin/eksport.json odrzuca zwykłego obywatela", %{conn: conn} do
    conn =
      conn
      |> log_in_user(user_fixture())
      |> get(~p"/admin/eksport.json")

    assert redirected_to(conn) == ~p"/"
  end

  test "GET /admin/eksport.json wymaga zalogowania", %{conn: conn} do
    conn = get(conn, ~p"/admin/eksport.json")
    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
