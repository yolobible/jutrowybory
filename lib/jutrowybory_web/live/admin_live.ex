defmodule JutrowyboryWeb.AdminLive do
  use JutrowyboryWeb, :live_view

  alias Jutrowybory.Survey
  alias Jutrowybory.Survey.Question
  alias Jutrowybory.Survey.Topic

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Panel admina")
     |> assign(:topics, Survey.list_topics())
     |> assign(:global, Survey.global_stats())
     |> assign(:stats, Survey.question_stats())
     |> assign(:topic_form, topic_form())
     |> assign(:question_form, question_form())
     |> allow_upload(:csv, accept: ~w(.csv), max_entries: 1, max_file_size: 1_000_000)}
  end

  @impl true
  def handle_event("validate_import", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save_import", _params, socket) do
    case consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
           {:ok, File.read!(path)}
         end) do
      [] ->
        {:noreply, put_flash(socket, :error, "Wybierz plik CSV przed importem.")}

      [content | _] ->
        {:ok, %{topics: topics, questions: questions, skipped: skipped}} =
          Survey.import_questions_csv(content)

        message = "Zaimportowano #{questions} pytań (#{topics} nowych tematów)."

        message =
          if skipped == [] do
            message
          else
            message <> " Pominięto błędne linie: #{Enum.join(skipped, ", ")}."
          end

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign(:topics, Survey.list_topics())
         |> assign(:global, Survey.global_stats())
         |> assign(:stats, Survey.question_stats())}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv, ref)}
  end

  def handle_event("validate_topic", %{"topic" => params}, socket) do
    {:noreply, assign(socket, :topic_form, topic_form(params))}
  end

  def handle_event("save_topic", %{"topic" => params}, socket) do
    case Survey.create_topic(params) do
      {:ok, _topic} ->
        {:noreply,
         socket
         |> put_flash(:info, "Temat został dodany.")
         |> assign(:topics, Survey.list_topics())
         |> assign(:topic_form, topic_form())}

      {:error, changeset} ->
        {:noreply, assign(socket, :topic_form, to_form(changeset))}
    end
  end

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

  defp topic_form(params \\ %{}) do
    Survey.change_topic(%Topic{}, params) |> to_form()
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

      <%!-- Import pytań z CSV --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm mb-8">
        <div class="card-body">
          <h2 class="card-title">Import pytań z CSV</h2>
          <p class="text-sm text-base-content/70">
            Format: <code class="font-mono">temat,treść pytania</code> — jedna para na linię.
            Nieistniejące tematy zostaną utworzone automatycznie. Pierwszy wiersz może być
            nagłówkiem (<code class="font-mono">temat,pytanie</code>).
          </p>
          <form id="admin-import-form" phx-change="validate_import" phx-submit="save_import">
            <div class="flex flex-col sm:flex-row items-start sm:items-center gap-3 mt-2">
              <.live_file_input
                upload={@uploads.csv}
                class="file-input file-input-bordered w-full sm:max-w-md"
              />
              <.button phx-disable-with="Importowanie..." class="btn btn-primary">
                Importuj
              </.button>
            </div>
            <div :for={entry <- @uploads.csv.entries} class="text-sm mt-2">
              {entry.client_name}
              <button
                type="button"
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                class="btn btn-ghost btn-xs"
                aria-label="Usuń"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
            <p :for={err <- upload_errors(@uploads.csv)} class="text-error text-sm mt-2">
              {error_to_string(err)}
            </p>
          </form>
        </div>
      </div>

      <%!-- Dodawanie tematu --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm mb-8">
        <div class="card-body">
          <h2 class="card-title">Dodaj nowy temat</h2>
          <.form
            for={@topic_form}
            id="admin-topic-form"
            phx-change="validate_topic"
            phx-submit="save_topic"
          >
            <.input
              field={@topic_form[:name]}
              type="text"
              label="Nazwa tematu"
              placeholder="np. Gospodarka"
              class="w-full"
            />
            <.button phx-disable-with="Zapisywanie..." class="btn btn-primary mt-2">
              Dodaj temat
            </.button>
          </.form>
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

  defp error_to_string(:too_large), do: "Plik jest za duży (maks. 1 MB)."
  defp error_to_string(:not_accepted), do: "Dozwolone są tylko pliki .csv."
  defp error_to_string(:too_many_files), do: "Można wybrać tylko jeden plik."
  defp error_to_string(err), do: "Błąd uploadu: #{inspect(err)}"
end
