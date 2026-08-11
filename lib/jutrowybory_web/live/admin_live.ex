defmodule JutrowyboryWeb.AdminLive do
  use JutrowyboryWeb, :live_view

  alias Jutrowybory.Survey
  alias Jutrowybory.Survey.Question

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Panel admina")
     |> assign(:topics, Survey.list_topics())
     |> assign(:global, Survey.global_stats())
     |> assign(:stats, Survey.question_stats())
     |> assign(:question_form, question_form())}
  end

  @impl true
  def handle_event("validate_question", %{"question" => params}, socket) do
    {:noreply, assign(socket, :question_form, question_form(params))}
  end

  def handle_event("save_question", %{"question" => params}, socket) do
    case Survey.create_question(params) do
      {:ok, _question} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pytanie zostało dodane.")
         |> assign(:stats, Survey.question_stats())
         |> assign(:global, Survey.global_stats())
         |> assign(:question_form, question_form())}

      {:error, changeset} ->
        {:noreply, assign(socket, :question_form, to_form(changeset))}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    question = Survey.get_question!(id)

    {:ok, _} =
      question
      |> Survey.change_question(%{active: !question.active})
      |> Jutrowybory.Repo.update()

    {:noreply, assign(socket, :stats, Survey.question_stats())}
  end

  defp question_form(params \\ %{}) do
    Survey.change_question(%Question{}, params) |> to_form()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-between flex-wrap gap-4 mb-6">
        <h1 class="text-2xl font-bold">Panel admina</h1>
        <a href={~p"/admin/eksport.json"} class="btn btn-secondary">
          <.icon name="hero-arrow-down-tray" class="size-5" /> Eksport statystyk (JSON)
        </a>
      </div>

      <%!-- Statystyki zbiorcze --%>
      <div class="stats stats-vertical sm:stats-horizontal shadow border border-base-300 w-full mb-8">
        <div class="stat">
          <div class="stat-title">Obywatele</div>
          <div class="stat-value text-primary">{@global.users}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Pytania</div>
          <div class="stat-value">{@global.questions}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Odpowiedzi</div>
          <div class="stat-value">{@global.answers}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Komentarze</div>
          <div class="stat-value">{@global.comments}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Głosy na komentarze</div>
          <div class="stat-value">{@global.votes}</div>
        </div>
      </div>

      <%!-- Dodawanie pytania --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm mb-8">
        <div class="card-body">
          <h2 class="card-title">Dodaj nowe pytanie</h2>
          <.form
            for={@question_form}
            id="admin-question-form"
            phx-change="validate_question"
            phx-submit="save_question"
          >
            <div class="flex flex-col sm:flex-row gap-3">
              <.input
                field={@question_form[:topic_id]}
                type="select"
                label="Temat"
                prompt="Wybierz temat"
                options={Enum.map(@topics, &{&1.name, &1.id})}
              />
              <.input field={@question_form[:position]} type="number" label="Kolejność" />
            </div>
            <.input
              field={@question_form[:text]}
              type="textarea"
              rows="5"
              label="Treść (po „Czy zgadzasz się z...”)"
              placeholder="np. podniesieniem podatku od nieruchomości"
              class="w-full"
            />
            <.button phx-disable-with="Zapisywanie..." class="btn btn-primary mt-2">
              Dodaj pytanie
            </.button>
          </.form>
        </div>
      </div>

      <%!-- Szczegółowe statystyki per pytanie --%>
      <h2 class="text-xl font-bold mb-4">Statystyki pytań</h2>
      <div class="space-y-6">
        <div
          :for={stat <- @stats}
          id={"stat-#{stat.question.id}"}
          class="card bg-base-100 border border-base-300 shadow-sm"
        >
          <div class="card-body gap-3">
            <div class="flex items-start justify-between gap-4 flex-wrap">
              <div>
                <h3 class="font-semibold">Czy zgadzasz się z {stat.question.text}</h3>
                <div class="text-sm text-base-content/60">
                  {stat.question.topic.name} · odpowiedzi: {stat.total} · komentarzy: {stat.comments_count}
                </div>
              </div>
              <div class="flex items-center gap-2">
                <span :if={stat.avg} class="badge badge-primary badge-lg">
                  średnia: {stat.avg} ({Jutrowybory.Survey.answer_label(round(stat.avg))})
                </span>
                <span :if={stat.median} class="badge badge-secondary badge-lg">
                  mediana: {stat.median} ({Jutrowybory.Survey.answer_label(stat.median)})
                </span>
                <button
                  phx-click="toggle_active"
                  phx-value-id={stat.question.id}
                  class={["btn btn-xs", (stat.question.active && "btn-outline") || "btn-warning"]}
                >
                  {if stat.question.active, do: "Dezaktywuj", else: "Aktywuj"}
                </button>
              </div>
            </div>

            <%!-- Histogram odpowiedzi 0..9 --%>
            <div class="flex items-end gap-1 h-28">
              <div
                :for={{count, value} <- Enum.with_index(stat.distribution)}
                class="flex flex-col items-center justify-end flex-1 h-full"
                title={"#{value}: #{count} odpowiedzi"}
              >
                <span class="text-[10px]">{if count > 0, do: count}</span>
                <div
                  class={[
                    "w-full rounded-t",
                    value <= 1 && "bg-error",
                    value == 2 && "bg-warning",
                    value >= 3 && "bg-success"
                  ]}
                  style={"height: #{bar_height(count, stat.distribution)}%"}
                />
                <span class="text-xs font-semibold mt-0.5">{value}</span>
              </div>
            </div>
            <div class="flex text-xs text-base-content/60">
              <span class="flex-1 text-left">zdecydowanie nie (0)</span>
              <span class="flex-1 text-center">raczej nie (1)</span>
              <span class="flex-1 text-center">nie wiem (2)</span>
              <span class="flex-1 text-center">raczej tak (3)</span>
              <span class="flex-1 text-right">zdecydowanie tak (4)</span>
            </div>

            <div :if={stat.top_comment} class="text-sm bg-base-200 rounded-lg p-3">
              <span class="font-semibold">Najwyżej oceniany komentarz</span>
              ({stat.top_comment.username}, wynik: {stat.top_comment.score}):
              <span class="italic">{stat.top_comment.body}</span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp bar_height(count, distribution) do
    max = Enum.max(distribution)

    if max > 0 do
      Float.round(count / max * 100, 1)
    else
      0
    end
  end
end
