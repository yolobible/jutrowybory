defmodule Jutrowybory.Survey do
  @moduledoc """
  Kontekst ankiety: tematy, pytania, odpowiedzi (skala 0-9),
  komentarze i głosy na komentarze.
  """

  import Ecto.Query, warn: false

  alias Jutrowybory.Repo
  alias Jutrowybory.Accounts.User
  alias Jutrowybory.Survey.{Answer, Comment, CommentVote, Question, Topic}

  ## Tematy

  def list_topics do
    Repo.all(from t in Topic, order_by: [asc: t.name])
  end

  def get_topic!(id), do: Repo.get!(Topic, id)

  def create_topic(attrs) do
    %Topic{}
    |> Topic.changeset(attrs)
    |> Repo.insert()
  end

  def change_topic(%Topic{} = topic, attrs \\ %{}) do
    Topic.changeset(topic, attrs)
  end

  ## Pytania

  def list_questions(nil) do
    Repo.all(
      from q in Question,
        where: q.active,
        order_by: [asc: q.position, asc: q.id],
        preload: [:topic]
    )
  end

  def list_questions(topic_id) do
    Repo.all(
      from q in Question,
        where: q.active and q.topic_id == ^topic_id,
        order_by: [asc: q.position, asc: q.id],
        preload: [:topic]
    )
  end

  def list_all_questions do
    Repo.all(
      from q in Question,
        order_by: [asc: q.position, asc: q.id],
        preload: [:topic]
    )
  end

  def get_question!(id), do: Repo.get!(Question, id)

  def create_question(attrs) do
    %Question{}
    |> Question.changeset(attrs)
    |> Repo.insert()
  end

  def change_question(%Question{} = question, attrs \\ %{}) do
    Question.changeset(question, attrs)
  end

  ## Odpowiedzi

  @doc "Mapa %{question_id => value} dla danego użytkownika."
  def answers_map(%User{id: user_id}) do
    from(a in Answer, where: a.user_id == ^user_id, select: {a.question_id, a.value})
    |> Repo.all()
    |> Map.new()
  end

  def upsert_answer(%User{id: user_id}, question_id, value) do
    now = DateTime.utc_now(:second)

    %Answer{}
    |> Answer.changeset(%{user_id: user_id, question_id: question_id, value: value})
    |> Repo.insert(
      on_conflict: [set: [value: value, updated_at: now]],
      conflict_target: [:user_id, :question_id]
    )
  end

  ## Komentarze

  @doc """
  Lista komentarzy do pytania, posortowana po wyniku (jak na Reddicie).
  Zwraca listę map: %{comment, username, score, user_vote}.
  """
  def list_comments(question_id, %User{id: user_id}) do
    from(c in Comment,
      join: u in assoc(c, :user),
      left_join: v in assoc(c, :votes),
      left_join: uv in CommentVote,
      on: uv.comment_id == c.id and uv.user_id == ^user_id,
      where: c.question_id == ^question_id,
      group_by: [c.id, u.id, uv.id],
      order_by: [desc: coalesce(sum(v.value), 0), desc: c.inserted_at],
      select: %{
        comment: c,
        username: u.username,
        score: coalesce(sum(v.value), 0),
        user_vote: uv.value
      }
    )
    |> Repo.all()
  end

  def create_comment(%User{id: user_id}, question_id, attrs) do
    %Comment{}
    |> Comment.changeset(Map.merge(attrs, %{"user_id" => user_id, "question_id" => question_id}))
    |> Repo.insert()
  end

  @doc "Etykieta słowna dla odpowiedzi 0-4."
  def answer_label(0), do: "zdecydowanie nie"
  def answer_label(1), do: "raczej nie"
  def answer_label(2), do: "nie wiem"
  def answer_label(3), do: "raczej tak"
  def answer_label(value) when value >= 4, do: "zdecydowanie tak"
  def answer_label(_), do: ""

  def delete_comment(%Comment{} = comment), do: Repo.delete(comment)

  def get_comment!(id), do: Repo.get!(Comment, id)

  ## Głosy

  @doc """
  Głosuje na komentarz (value: 1 albo -1). Ponowny klik w ten sam głos
  cofa głos (toggle), klik w przeciwny zmienia jego znak.
  """
  def vote_comment(%User{id: user_id}, comment_id, value) when value in [-1, 1] do
    case Repo.get_by(CommentVote, user_id: user_id, comment_id: comment_id) do
      nil ->
        %CommentVote{}
        |> CommentVote.changeset(%{user_id: user_id, comment_id: comment_id, value: value})
        |> Repo.insert()

      %CommentVote{value: ^value} = vote ->
        Repo.delete(vote)

      %CommentVote{} = vote ->
        vote
        |> CommentVote.changeset(%{value: value})
        |> Repo.update()
    end
  end

  @doc """
  Publiczne, zagregowane wyniki per pytanie (bez danych o użytkownikach):
  %{question_id => %{total, avg, distribution}} — distribution to liczności 0..4.
  """
  def public_results do
    from(a in Answer,
      group_by: [a.question_id, a.value],
      select: %{question_id: a.question_id, value: a.value, count: count(a.id)}
    )
    |> Repo.all()
    |> Enum.group_by(& &1.question_id)
    |> Map.new(fn {question_id, rows} ->
      distribution = for v <- 0..4, do: Enum.find_value(rows, 0, &if(&1.value == v, do: &1.count))
      total = Enum.sum(distribution)

      avg =
        if total > 0 do
          sum =
            distribution |> Enum.with_index() |> Enum.reduce(0, fn {c, v}, acc -> acc + c * v end)

          Float.round(sum / total, 1)
        end

      {question_id, %{total: total, avg: avg, distribution: distribution}}
    end)
  end

  ## Statystyki (panel admina)

  @doc """
  Szczegółowe statystyki per pytanie. Zwraca listę map:
  %{question, total, avg, median, distribution, comments_count, top_comment}
  gdzie distribution to lista 10 elementów (liczności dla wartości 0..9).
  """
  def question_stats do
    questions = list_all_questions()

    dist_rows =
      Repo.all(
        from a in Answer,
          group_by: [a.question_id, a.value],
          select: %{question_id: a.question_id, value: a.value, count: count(a.id)}
      )

    comment_rows =
      Repo.all(
        from c in Comment,
          group_by: c.question_id,
          select: %{question_id: c.question_id, count: count(c.id)}
      )

    top_comments =
      Repo.all(
        from c in Comment,
          join: u in assoc(c, :user),
          left_join: v in assoc(c, :votes),
          group_by: [c.id, u.id],
          select: %{
            question_id: c.question_id,
            body: c.body,
            username: u.username,
            score: coalesce(sum(v.value), 0)
          }
      )
      |> Enum.group_by(& &1.question_id)
      |> Map.new(fn {qid, rows} ->
        {qid, Enum.max_by(rows, & &1.score, fn -> nil end)}
      end)

    dist_by_question = Enum.group_by(dist_rows, & &1.question_id)
    comments_by_question = Map.new(comment_rows, &{&1.question_id, &1.count})

    Enum.map(questions, fn q ->
      rows = Map.get(dist_by_question, q.id, [])
      distribution = for v <- 0..4, do: Enum.find_value(rows, 0, &if(&1.value == v, do: &1.count))
      total = Enum.sum(distribution)

      avg =
        if total > 0 do
          sum =
            distribution |> Enum.with_index() |> Enum.reduce(0, fn {c, v}, acc -> acc + c * v end)

          Float.round(sum / total, 2)
        end

      %{
        question: q,
        total: total,
        avg: avg,
        median: median(distribution),
        distribution: distribution,
        comments_count: Map.get(comments_by_question, q.id, 0),
        top_comment: Map.get(top_comments, q.id)
      }
    end)
  end

  defp median(distribution) do
    total = Enum.sum(distribution)

    if total == 0 do
      nil
    else
      mid = div(total - 1, 2)

      distribution
      |> Enum.with_index()
      |> Enum.reduce_while({0, nil}, fn {count, value}, {seen, _} ->
        seen = seen + count

        if seen > mid do
          {:halt, {seen, value}}
        else
          {:cont, {seen, nil}}
        end
      end)
      |> elem(1)
    end
  end

  @doc "Zbiorcze statystyki portalu."
  def global_stats do
    %{
      users: Repo.aggregate(User, :count),
      questions: Repo.aggregate(Question, :count),
      answers: Repo.aggregate(Answer, :count),
      comments: Repo.aggregate(Comment, :count),
      votes: Repo.aggregate(CommentVote, :count)
    }
  end
end
