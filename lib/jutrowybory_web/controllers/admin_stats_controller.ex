defmodule JutrowyboryWeb.AdminStatsController do
  use JutrowyboryWeb, :controller

  alias Jutrowybory.Survey

  @doc "Eksport statystyk do pliku JSON (tylko admin)."
  def export(conn, _params) do
    stats = Survey.question_stats()

    data = %{
      wygenerowano: DateTime.utc_now(:second),
      globalne: Survey.global_stats(),
      pytania: Enum.map(stats, &question_json/1)
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_download({:binary, Jason.encode!(data, pretty: true)},
      filename: "statystyki-jutrowybory.json"
    )
  end

  defp question_json(stat) do
    %{
      id: stat.question.id,
      pytanie: "Czy zgadzasz się z #{stat.question.text}",
      temat: stat.question.topic.name,
      aktywne: stat.question.active,
      odpowiedzi: stat.total,
      srednia: stat.avg,
      mediana: stat.median,
      rozklad: distribution_json(stat.distribution),
      komentarze: stat.comments_count,
      najlepszy_komentarz: top_comment_json(stat.top_comment)
    }
  end

  defp distribution_json(distribution) do
    distribution
    |> Enum.with_index()
    |> Map.new(fn {count, value} -> {Survey.answer_label(value), count} end)
  end

  defp top_comment_json(nil), do: nil

  defp top_comment_json(top) do
    %{autor: top.username, tresc: top.body, wynik: top.score}
  end
end
