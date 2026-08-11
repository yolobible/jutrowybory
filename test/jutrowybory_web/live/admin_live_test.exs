defmodule JutrowyboryWeb.AdminLiveTest do
  use JutrowyboryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jutrowybory.AccountsFixtures

  alias Jutrowybory.Survey

  defp admin_fixture do
    user = user_fixture()

    user
    |> Ecto.Changeset.change(role: "admin")
    |> Jutrowybory.Repo.update!()
  end

  setup do
    {:ok, topic} = Survey.create_topic(%{name: "Gospodarka"})

    {:ok, question} =
      Survey.create_question(%{text: "podwyższeniem płacy minimalnej", topic_id: topic.id})

    %{topic: topic, question: question}
  end

  test "renderuje statystyki i pozwala dodać pytanie", %{
    conn: conn,
    topic: topic,
    question: question
  } do
    admin = admin_fixture()
    voter = user_fixture()
    {:ok, _} = Survey.upsert_answer(voter, question.id, 3)

    {:ok, view, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin")

    assert html =~ "Panel admina"
    assert html =~ "podwyższeniem płacy minimalnej"
    assert html =~ "średnia: 3.0 (raczej tak)"
    assert html =~ "mediana: 3"

    view
    |> form("#admin-question-form",
      question: %{text: "bezpłatną komunikacją miejską", topic_id: topic.id, position: 2}
    )
    |> render_submit()

    html = render(view)
    assert html =~ "bezpłatną komunikacją miejską"
    assert Survey.list_questions(topic.id) |> Enum.map(& &1.text) |> length() == 2
  end

  test "dezaktywuje pytanie", %{conn: conn, question: question} do
    {:ok, view, _html} =
      conn
      |> log_in_user(admin_fixture())
      |> live(~p"/admin")

    view
    |> element("#stat-#{question.id} button", "Dezaktywuj")
    |> render_click()

    refute Survey.get_question!(question.id).active
    assert render(view) =~ "Aktywuj"
  end
end
