defmodule JutrowyboryWeb.SurveyLiveTest do
  use JutrowyboryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jutrowybory.AccountsFixtures
  import Ecto.Query

  alias Jutrowybory.Survey

  setup do
    {:ok, topic} = Survey.create_topic(%{name: "Gospodarka"})

    {:ok, question} =
      Survey.create_question(%{text: "podwyższeniem płacy minimalnej", topic_id: topic.id})

    %{topic: topic, question: question}
  end

  test "przekierowuje niezalogowanego użytkownika", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/ankieta")
  end

  test "renderuje pytanie i zapisuje odpowiedź z suwaka", %{conn: conn, question: question} do
    user = user_fixture()

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/ankieta")

    assert html =~ "Czy zgadzasz się z podwyższeniem płacy minimalnej"
    assert html =~ "Gospodarka"

    view
    |> element("#question-#{question.id} form[phx-change='answer']")
    |> render_change(%{"question_id" => question.id, "value" => "4"})

    assert Survey.answers_map(user) == %{question.id => 4}
    assert render(view) =~ "Twoja odpowiedź: zdecydowanie tak"
  end

  test "dodaje komentarz i głosuje", %{conn: conn, question: question} do
    user = user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/ankieta")

    view
    |> element("#question-#{question.id} form[phx-submit='add_comment']")
    |> render_submit(%{"question_id" => question.id, "body" => "Świetny pomysł"})

    html = render(view)
    assert html =~ "Świetny pomysł"
    assert html =~ user.username

    [comment] = Jutrowybory.Repo.all(Survey.Comment)

    view
    |> element("#comment-#{comment.id} button[phx-value-vote='1']")
    |> render_click()

    assert [%{score: 1, user_vote: 1}] = Survey.list_comments(question.id, user)
  end

  test "filtruje pytania po temacie", %{conn: conn, topic: topic} do
    {:ok, inny} = Survey.create_topic(%{name: "Kultura"})

    {:ok, _} =
      Survey.create_question(%{text: "dotacjami dla teatrów", topic_id: inny.id})

    {:ok, _view, html} =
      conn
      |> log_in_user(user_fixture())
      |> live(~p"/ankieta?temat=#{topic.id}")

    assert html =~ "podwyższeniem płacy minimalnej"
    refute html =~ "dotacjami dla teatrów"
  end

  test "panel admina niedostępny dla zwykłego obywatela", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} =
             conn
             |> log_in_user(user_fixture())
             |> live(~p"/admin")
  end

  test "tylko jeden komentarz pod pytaniem — formularz znika po dodaniu", %{
    conn: conn,
    question: question
  } do
    {:ok, view, _html} =
      conn
      |> log_in_user(user_fixture())
      |> live(~p"/ankieta")

    view
    |> element("#comment-form-#{question.id}")
    |> render_submit(%{"question_id" => question.id, "body" => "Mój jedyny komentarz"})

    html = render(view)
    assert html =~ "Mój jedyny komentarz"
    refute has_element?(view, "#comment-form-#{question.id}")
    assert html =~ "Dodałeś/aś już swój komentarz"
  end

  test "pokazuje 5 komentarzy, przełącznik i przycisk pokaż więcej", %{
    conn: conn,
    question: question
  } do
    comments =
      for n <- 1..7 do
        {:ok, comment} =
          Survey.create_comment(user_fixture(), question.id, %{"body" => "Komentarz #{n}"})

        comment
      end

    # odrębne znaczniki czasu, żeby kolejność "najnowsze" była deterministyczna
    comments
    |> Enum.with_index()
    |> Enum.each(fn {comment, n} ->
      Jutrowybory.Repo.update_all(
        from(c in Survey.Comment, where: c.id == ^comment.id),
        set: [inserted_at: DateTime.add(~U[2020-01-01 00:00:00Z], n, :second)]
      )
    end)

    {:ok, view, html} =
      conn
      |> log_in_user(user_fixture())
      |> live(~p"/ankieta")

    assert html =~ "Najlepsze"
    assert html =~ "Najnowsze"
    assert html =~ "Pokaż więcej komentarzy"
    # widoczne 5 z 7
    assert html |> String.split("Komentarz ") |> length() == 6

    view
    |> element("button", "Pokaż więcej komentarzy")
    |> render_click()

    html = render(view)
    assert html =~ "Komentarz 7"
    refute html =~ "Pokaż więcej komentarzy"

    view
    |> element("button", "Najnowsze")
    |> render_click()

    # najnowszy pierwszy
    assert render(view) =~ ~r/Komentarz 7.*Komentarz 6/s
  end

  test "etykieta słowna odpowiedzi", %{conn: conn, question: question} do
    {:ok, view, _html} =
      conn
      |> log_in_user(user_fixture())
      |> live(~p"/ankieta")

    view
    |> element("#answer-form-#{question.id}")
    |> render_change(%{"question_id" => question.id, "value" => "4"})

    assert render(view) =~ "Twoja odpowiedź: zdecydowanie tak"
  end

  test "wyniki społeczności widoczne dopiero po odpowiedzi", %{conn: conn, question: question} do
    other = user_fixture()
    {:ok, _} = Survey.upsert_answer(other, question.id, 3)

    {:ok, view, html} =
      conn
      |> log_in_user(user_fixture())
      |> live(~p"/ankieta")

    assert html =~ "Odpowiedz na pytanie, aby zobaczyć wyniki społeczności"
    refute html =~ "Wyniki społeczności:"

    view
    |> element("#answer-form-#{question.id}")
    |> render_change(%{"question_id" => question.id, "value" => "4"})

    html = render(view)
    assert html =~ "Wyniki społeczności: 2 odpowiedzi · średnia: zdecydowanie tak"
    refute html =~ "3.5"
  end
end
