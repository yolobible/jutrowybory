# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
alias Jutrowybory.{Accounts, Repo, Survey}
alias Jutrowybory.Accounts.User

## Tematy i pytania

topics_with_questions = %{
  "Gospodarka" => [
    "podwyższeniem płacy minimalnej",
    "wprowadzeniem podatku od wielkich korporacji",
    "skróceniem tygodnia pracy do 4 dni",
    "państwowym wsparciem dla małych firm"
  ],
  "Kultura" => [
    "zwiększeniem dotacji na muzea i teatry",
    "darmowym dostępem do instytucji kultury dla studentów",
    "finansowaniem kultury z budżetu państwa ponad 1%"
  ],
  "Edukacja" => [
    "zniesieniem prac domowych w szkołach podstawowych",
    "bezpłatnymi studiami dla wszystkich",
    "obowiązkowymi lekcjami programowania od podstawówki",
    "powrotem do egzaminów wstępnych na studia"
  ],
  "Zdrowie" => [
    "bezpłatną stomatologią w publicznej służbie zdrowia",
    "zakazem sprzedaży energi drinków nieletnim",
    "obowiązkowymi szczepieniami dzieci"
  ],
  "Bezpieczeństwo" => [
    "zwiększeniem liczby policjantów na ulicach",
    "rozszerzeniem monitoringu miejskiego",
    "zaostrzeniem kar za przemoc domową"
  ],
  "Środowisko" => [
    "zakazem sprzedaży aut spalinowych od 2035 roku",
    "obowiązkową segregacją odpadów z karami finansowymi",
    "rozbudową terenów zielonych kosztem parkingów"
  ],
  "Infrastruktura" => [
    "budową szybkiej kolei między największymi miastami",
    "bezpłatną komunikacją miejską",
    "ograniczeniem ruchu samochodowego w centrach miast"
  ],
  "Praca" => [
    "ustawowym prawem do pracy zdalnej",
    "pełną transparentnością wynagrodzeń w ogłoszeniach o pracę",
    "dłuższymi urlopami ojcowskimi"
  ],
  "Technologia" => [
    "ograniczeniem użycia sztucznej inteligencji w urzędach",
    "państwowym programem nauki programowania dla dorosłych",
    "zakazem telefonów w szkołach"
  ],
  "Sport" => [
    "finansowaniem sportów amatorskich z budżetu państwa",
    "bezpłatnym dostępem do miejskich siłowni i basenów",
    "obowiązkową wf-em codziennie w szkołach"
  ]
}

topics =
  for {topic_name, questions} <- topics_with_questions do
    topic =
      case Repo.get_by(Survey.Topic, name: topic_name) do
        nil ->
          {:ok, topic} = Survey.create_topic(%{name: topic_name})
          topic

        topic ->
          topic
      end

    questions
    |> Enum.with_index(1)
    |> Enum.each(fn {text, position} ->
      unless Repo.get_by(Survey.Question, text: text) do
        {:ok, _} =
          Survey.create_question(%{text: text, topic_id: topic.id, position: position})
      end
    end)

    topic
  end

## Użytkownicy

admin =
  case Accounts.get_user_by_email("admin@jutrowybory.pl") do
    nil ->
      {:ok, user} =
        Accounts.register_user(%{email: "admin@jutrowybory.pl", password: "adminadmin12"})

      user
      |> Ecto.Changeset.change(role: "admin")
      |> Repo.update!()

    user ->
      user
  end

IO.puts("Admin: admin@jutrowybory.pl / adminadmin12 (#{admin.username})")

demo_users =
  for n <- 1..8 do
    email = "demo#{n}@jutrowybory.pl"

    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.register_user(%{email: email, password: "demodemo1234"})
        user

      user ->
        user
    end
  end

## Przykładowe odpowiedzi, komentarze i głosy (tylko przy pustej bazie)

if Repo.aggregate(Survey.Answer, :count) == 0 do
  questions = Survey.list_all_questions()

  sample_comments = [
    "To jedno z najważniejszych postanowień, popieram w pełni.",
    "Pomysł dobry, ale skąd wziąć na to pieniądze?",
    "Zdecydowanie przeciw — to uderzy w zwykłych ludzi.",
    "W innych krajach to działa, czemu u nas miałoby nie działać?",
    "Potrzebne są konkrety, a nie tylko hasła.",
    "Mam mieszane uczucia, ale raczej popieram."
  ]

  for user <- demo_users, question <- questions do
    if :rand.uniform(100) <= 80 do
      {:ok, _} = Survey.upsert_answer(user, question.id, :rand.uniform(5) - 1)
    end
  end

  comments =
    for question <- questions do
      demo_users
      |> Enum.take_random(:rand.uniform(8))
      |> Enum.map(fn user ->
        body = Enum.random(sample_comments)
        {:ok, comment} = Survey.create_comment(user, question.id, %{"body" => body})
        comment
      end)
    end
    |> List.flatten()

  for comment <- comments, user <- Enum.take_random(demo_users, :rand.uniform(6)) do
    if user.id != comment.user_id do
      value = if :rand.uniform(100) <= 70, do: 1, else: -1
      Survey.vote_comment(user, comment.id, value)
    end
  end

  IO.puts("Dodano przykładowe odpowiedzi, komentarze i głosy.")
end

IO.puts("Seed zakończony. Tematy: #{length(topics)}")
_ = User
