defmodule JutrowyboryWeb.SurveyLive do
  use JutrowyboryWeb, :live_view

  alias Jutrowybory.Accounts.User
  alias Jutrowybory.Survey

  @comments_page_size 5

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:page_title, "Ankieta")
     |> assign(:user, user)
     |> assign(:topics, Survey.list_topics())
     |> assign(:comment_view, %{})}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    topic_id =
      case params["temat"] do
        nil -> nil
        "" -> nil
        id -> String.to_integer(id)
      end

    questions = Survey.list_questions(topic_id)
    user = socket.assigns.user

    {:noreply,
     socket
     |> assign(:current_topic_id, topic_id)
     |> assign(:questions, questions)
     |> assign(:answers, Survey.answers_map(user))
     |> assign(:results, Survey.public_results())
     |> assign(:comments, load_comments(questions, user))}
  end

  @impl true
  def handle_event("answer", %{"question_id" => qid, "value" => value}, socket) do
    user = socket.assigns.user
    value = String.to_integer(value)

    case Survey.upsert_answer(user, qid, value) do
      {:ok, _answer} ->
        answers = Map.put(socket.assigns.answers, String.to_integer(qid), value)

        {:noreply,
         socket
         |> assign(:answers, answers)
         |> assign(:results, Survey.public_results())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Nie udało się zapisać odpowiedzi.")}
    end
  end

  def handle_event("add_comment", %{"question_id" => qid, "body" => body}, socket) do
    user = socket.assigns.user

    case Survey.create_comment(user, qid, %{"body" => body}) do
      {:ok, _comment} ->
        {:noreply, reload_comments(socket, String.to_integer(qid))}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Nie dodano komentarza — jest pusty albo już skomentowałeś/aś to pytanie."
         )}
    end
  end

  def handle_event("vote", %{"comment_id" => cid, "question_id" => qid, "vote" => value}, socket) do
    Survey.vote_comment(socket.assigns.user, String.to_integer(cid), String.to_integer(value))
    {:noreply, reload_comments(socket, String.to_integer(qid))}
  end

  def handle_event("delete_comment", %{"comment_id" => cid, "question_id" => qid}, socket) do
    comment = Survey.get_comment!(cid)
    user = socket.assigns.user

    if comment.user_id == user.id or User.admin?(user) do
      {:ok, _} = Survey.delete_comment(comment)
    end

    {:noreply, reload_comments(socket, String.to_integer(qid))}
  end

  def handle_event("comments_sort", %{"question_id" => qid, "sort" => sort}, socket) do
    sort = if sort == "newest", do: :newest, else: :top

    {:noreply,
     update(socket, :comment_view, fn views ->
       Map.update(views, String.to_integer(qid), %{sort: sort, shown: @comments_page_size}, &Map.put(&1, :sort, sort))
     end)}
  end

  def handle_event("comments_more", %{"question_id" => qid}, socket) do
    {:noreply,
     update(socket, :comment_view, fn views ->
       Map.update(views, String.to_integer(qid), %{sort: :top, shown: @comments_page_size * 2}, fn view ->
         Map.update(view, :shown, @comments_page_size, &(&1 + @comments_page_size))
       end)
     end)}
  end

  defp load_comments(questions, user) do
    Map.new(questions, fn q -> {q.id, Survey.list_comments(q.id, user)} end)
  end

  defp reload_comments(socket, question_id) do
    comments = Survey.list_comments(question_id, socket.assigns.user)
    assign(socket, :comments, Map.put(socket.assigns.comments, question_id, comments))
  end

  # Zwraca {widoczne_komentarze, łączna_liczba, czy_są_jeszcze} dla pytania.
  defp visible_comments(assigns, question_id) do
    comments = assigns.comments[question_id] || []
    view = Map.get(assigns.comment_view, question_id, %{sort: :top, shown: @comments_page_size})

    sorted =
      case view.sort do
        :newest -> Enum.sort_by(comments, & &1.comment.inserted_at, {:desc, DateTime})
        _ -> comments
      end

    {Enum.take(sorted, view.shown), length(comments), length(sorted) > view.shown, view.sort}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-col lg:flex-row gap-8">
        <%!-- Menu tematów po lewej stronie --%>
        <aside class="lg:w-64 shrink-0 lg:sticky lg:top-8 lg:self-start lg:max-h-[calc(100vh-4rem)] lg:overflow-y-auto">
          <h2 class="text-lg font-bold mb-3">Tematy</h2>
          <ul class="menu bg-base-200 rounded-box w-full">
            <li>
              <.link patch={~p"/ankieta"} class={is_nil(@current_topic_id) && "active font-semibold"}>
                Wszystkie
              </.link>
            </li>
            <li :for={topic <- @topics}>
              <.link
                patch={~p"/ankieta?temat=#{topic.id}"}
                class={@current_topic_id == topic.id && "active font-semibold"}
              >
                {topic.name}
              </.link>
            </li>
          </ul>
        </aside>

        <div class="flex-1 space-y-8">
          <div :if={@questions == []} class="alert">
            Brak pytań w tym temacie.
          </div>

          <div
            :for={question <- @questions}
            id={"question-#{question.id}"}
            class="card bg-base-100 border border-base-300 shadow-sm"
          >
            <div class="card-body gap-4">
              <div class="flex items-start justify-between gap-4">
                <h3 class="card-title text-base sm:text-lg">
                  Czy zgadzasz się z {question.text}
                </h3>
                <span class="badge badge-outline shrink-0">{question.topic.name}</span>
              </div>

              <%!-- Suwak 0-9 z etykietami słownymi --%>
              <form phx-change="answer" id={"answer-form-#{question.id}"} class="w-full">
                <input type="hidden" name="question_id" value={question.id} />
                <div class="flex items-center gap-4">
                  <span class="text-xs font-semibold text-error whitespace-nowrap">
                    zdecydowanie nie
                  </span>
                  <input
                    type="range"
                    name="value"
                    min="0"
                    max="4"
                    step="1"
                    value={Map.get(@answers, question.id, 2)}
                    class={[
                      "range flex-1",
                      answer_range_class(Map.get(@answers, question.id))
                    ]}
                  />
                  <span class="text-xs font-semibold text-success whitespace-nowrap">
                    zdecydowanie tak
                  </span>
                </div>
                <div class="flex text-[10px] text-base-content/60 mt-1">
                  <span class="flex-1 text-left">zdecydowanie nie</span>
                  <span class="flex-1 text-center">raczej nie</span>
                  <span class="flex-1 text-center">nie wiem</span>
                  <span class="flex-1 text-center">raczej tak</span>
                  <span class="flex-1 text-right">zdecydowanie tak</span>
                </div>
              </form>
              <div class="flex items-center gap-2 text-sm">
                <span
                  :if={Map.has_key?(@answers, question.id)}
                  class={["badge badge-lg", answer_badge_class(@answers[question.id])]}
                >
                  Twoja odpowiedź: {Survey.answer_label(@answers[question.id])}
                </span>
                <span :if={!Map.has_key?(@answers, question.id)} class="text-base-content/60">
                  Przesuń suwak, aby odpowiedzieć
                </span>
              </div>

              <%!-- Wyniki społeczności — widoczne po udzieleniu odpowiedzi --%>
              <% result = @results[question.id] %>
              <div :if={Map.has_key?(@answers, question.id) && result && result.total > 0}>
                <div class="text-xs text-base-content/60 mb-1">
                  Wyniki społeczności: {result.total} odpowiedzi · średnia: {Survey.answer_label(round(result.avg))}
                </div>
                <div class="flex items-end gap-1 h-12">
                  <div
                    :for={{count, value} <- Enum.with_index(result.distribution)}
                    class="flex flex-col items-center justify-end flex-1 h-full"
                    title={"#{Survey.answer_label(value)}: #{count}"}
                  >
                    <div
                      class={[
                        "w-full rounded-t",
                        value <= 1 && "bg-error/70",
                        value == 2 && "bg-warning/70",
                        value >= 3 && "bg-success/70"
                      ]}
                      style={"height: #{bar_pct(count, result.distribution)}%"}
                    />
                  </div>
                </div>
                <div class="flex text-[10px] text-base-content/60">
                  <span class="flex-1 text-left">zdec. nie</span>
                  <span class="flex-1 text-center">raczej nie</span>
                  <span class="flex-1 text-center">nie wiem</span>
                  <span class="flex-1 text-center">raczej tak</span>
                  <span class="flex-1 text-right">zdec. tak</span>
                </div>
              </div>
              <p :if={!Map.has_key?(@answers, question.id)} class="text-xs text-base-content/50">
                Odpowiedz na pytanie, aby zobaczyć wyniki społeczności.
              </p>

              <%!-- Komentarze --%>
              <div class="divider my-1">
                Komentarze ({length(@comments[question.id] || [])})
              </div>

              <% user_commented? =
                Enum.any?(@comments[question.id] || [], &(&1.comment.user_id == @user.id)) %>

              <form
                :if={!user_commented?}
                phx-submit="add_comment"
                id={"comment-form-#{question.id}"}
                class="flex flex-col gap-2"
              >
                <input type="hidden" name="question_id" value={question.id} />
                <textarea
                  name="body"
                  rows="5"
                  placeholder="Dodaj komentarz (tylko jeden pod pytaniem)..."
                  class="textarea textarea-bordered w-full"
                  maxlength="2000"
                ></textarea>
                <button type="submit" class="btn btn-primary self-end">Dodaj</button>
              </form>
              <p :if={user_commented?} class="text-xs text-base-content/60">
                Dodałeś/aś już swój komentarz pod tym pytaniem.
              </p>

              <% {visible, _total, more?, sort} = visible_comments(assigns, question.id) %>

              <div :if={visible != []} class="flex gap-2 text-xs">
                <button
                  type="button"
                  phx-click="comments_sort"
                  phx-value-question_id={question.id}
                  phx-value-sort="top"
                  class={["btn btn-xs", sort == :top && "btn-primary" || "btn-ghost"]}
                >
                  Najlepsze
                </button>
                <button
                  type="button"
                  phx-click="comments_sort"
                  phx-value-question_id={question.id}
                  phx-value-sort="newest"
                  class={["btn btn-xs", sort == :newest && "btn-primary" || "btn-ghost"]}
                >
                  Najnowsze
                </button>
              </div>

              <ul class="space-y-2">
                <li
                  :for={c <- visible}
                  id={"comment-#{c.comment.id}"}
                  class="flex gap-3 items-start bg-base-200 rounded-lg p-3"
                >
                  <div class="flex flex-col items-center gap-0.5 shrink-0">
                    <button
                      type="button"
                      phx-click="vote"
                      phx-value-comment_id={c.comment.id}
                      phx-value-question_id={question.id}
                      phx-value-vote="1"
                      class={[
                        "btn btn-ghost btn-xs px-1",
                        c.user_vote == 1 && "text-success"
                      ]}
                      title="Głos za"
                    >
                      <.icon name="hero-arrow-up" class="size-4" />
                    </button>
                    <span class={[
                      "text-sm font-bold",
                      c.score > 0 && "text-success",
                      c.score < 0 && "text-error"
                    ]}>
                      {c.score}
                    </span>
                    <button
                      type="button"
                      phx-click="vote"
                      phx-value-comment_id={c.comment.id}
                      phx-value-question_id={question.id}
                      phx-value-vote="-1"
                      class={[
                        "btn btn-ghost btn-xs px-1",
                        c.user_vote == -1 && "text-error"
                      ]}
                      title="Głos przeciw"
                    >
                      <.icon name="hero-arrow-down" class="size-4" />
                    </button>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="text-xs text-base-content/60 mb-1">
                      <span class="font-semibold">{c.username}</span>
                      · {Calendar.strftime(c.comment.inserted_at, "%d.%m.%Y %H:%M")}
                    </div>
                    <p class="text-sm whitespace-pre-wrap break-words">{c.comment.body}</p>
                  </div>
                  <button
                    :if={c.comment.user_id == @user.id or User.admin?(@user)}
                    type="button"
                    phx-click="delete_comment"
                    phx-value-comment_id={c.comment.id}
                    phx-value-question_id={question.id}
                    class="btn btn-ghost btn-xs text-error shrink-0"
                    title="Usuń komentarz"
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </li>
              </ul>

              <button
                :if={more?}
                type="button"
                phx-click="comments_more"
                phx-value-question_id={question.id}
                class="btn btn-outline btn-sm w-full"
              >
                Pokaż więcej komentarzy
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp answer_range_class(nil), do: ""
  defp answer_range_class(value) when value <= 1, do: "range-error"
  defp answer_range_class(2), do: "range-warning"
  defp answer_range_class(_value), do: "range-success"

  defp answer_badge_class(0), do: "bg-error text-error-content border-error"
  defp answer_badge_class(1), do: "bg-error/50 text-error-content border-error/50"
  defp answer_badge_class(2), do: "bg-warning text-warning-content border-warning"
  defp answer_badge_class(3), do: "bg-success/60 text-success-content border-success/60"
  defp answer_badge_class(_), do: "bg-success text-success-content border-success"

  defp bar_pct(count, distribution) do
    max = Enum.max(distribution)
    if max > 0, do: Float.round(count / max * 100, 1), else: 0
  end
end
