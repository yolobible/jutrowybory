defmodule Jutrowybory.SurveyTest do
  use Jutrowybory.DataCase, async: true

  import Jutrowybory.AccountsFixtures

  alias Jutrowybory.Survey

  defp topic_fixture(attrs \\ %{}) do
    name = "Temat #{System.unique_integer()}"

    {:ok, topic} =
      attrs
      |> Enum.into(%{name: name})
      |> Survey.create_topic()

    topic
  end

  defp question_fixture(attrs \\ %{}) do
    topic = Map.get_lazy(attrs, :topic, fn -> topic_fixture() end)

    {:ok, question} =
      attrs
      |> Enum.into(%{text: "testowym pytaniem", topic_id: topic.id})
      |> Survey.create_question()

    question
  end

  describe "answers" do
    test "upsert_answer/3 zapisuje i nadpisuje odpowiedź" do
      user = user_fixture()
      question = question_fixture()

      assert {:ok, _} = Survey.upsert_answer(user, question.id, 2)
      assert Survey.answers_map(user) == %{question.id => 2}

      assert {:ok, _} = Survey.upsert_answer(user, question.id, 4)
      assert Survey.answers_map(user) == %{question.id => 4}
    end

    test "upsert_answer/3 odrzuca wartości spoza 0..4" do
      user = user_fixture()
      question = question_fixture()

      assert {:error, _} = Survey.upsert_answer(user, question.id, 5)
      assert {:error, _} = Survey.upsert_answer(user, question.id, -1)
    end
  end

  describe "comments and votes" do
    test "create_comment/3 i list_comments/2 z wynikiem głosów" do
      author = user_fixture()
      voter = user_fixture()
      question = question_fixture()

      {:ok, comment} = Survey.create_comment(author, question.id, %{"body" => "Komentarz"})

      assert [%{comment: %{id: _}, score: 0, user_vote: nil, username: username}] =
               Survey.list_comments(question.id, voter)

      assert username == author.username

      {:ok, _} = Survey.vote_comment(voter, comment.id, 1)
      assert [%{score: 1, user_vote: 1}] = Survey.list_comments(question.id, voter)

      # ponowny klik cofa głos
      {:ok, _} = Survey.vote_comment(voter, comment.id, 1)
      assert [%{score: 0, user_vote: nil}] = Survey.list_comments(question.id, voter)

      # zmiana głosu na przeciwny
      {:ok, _} = Survey.vote_comment(voter, comment.id, -1)
      assert [%{score: -1, user_vote: -1}] = Survey.list_comments(question.id, voter)
    end

    test "create_comment/3 odrzuca pusty komentarz" do
      user = user_fixture()
      question = question_fixture()

      assert {:error, _} = Survey.create_comment(user, question.id, %{"body" => ""})
    end

    test "create_comment/3 pozwala na tylko jeden komentarz pod pytaniem" do
      user = user_fixture()
      question = question_fixture()

      assert {:ok, _} = Survey.create_comment(user, question.id, %{"body" => "Pierwszy"})

      assert {:error, changeset} =
               Survey.create_comment(user, question.id, %{"body" => "Drugi"})

      assert "możesz dodać tylko jeden komentarz pod tym pytaniem" in errors_on(changeset).user_id
    end
  end

  describe "answer_label/1" do
    test "mapuje wartości 0-4 na etykiety słowne" do
      assert Survey.answer_label(0) == "zdecydowanie nie"
      assert Survey.answer_label(1) == "raczej nie"
      assert Survey.answer_label(2) == "nie wiem"
      assert Survey.answer_label(3) == "raczej tak"
      assert Survey.answer_label(4) == "zdecydowanie tak"
    end
  end

  describe "stats" do
    test "question_stats/0 liczy rozkład, średnią i medianę" do
      question = question_fixture()
      u1 = user_fixture()
      u2 = user_fixture()
      u3 = user_fixture()

      {:ok, _} = Survey.upsert_answer(u1, question.id, 0)
      {:ok, _} = Survey.upsert_answer(u2, question.id, 2)
      {:ok, _} = Survey.upsert_answer(u3, question.id, 4)

      stats = Enum.find(Survey.question_stats(), &(&1.question.id == question.id))

      assert stats.total == 3
      assert stats.avg == 2.0
      assert stats.median == 2
      assert stats.distribution == [1, 0, 1, 0, 1]
    end

    test "global_stats/0" do
      stats = Survey.global_stats()

      assert Enum.sort(Map.keys(stats)) == [
               :answers,
               :comments,
               :questions,
               :users,
               :votes
             ]
    end
  end
end
