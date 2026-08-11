defmodule Jutrowybory.Repo.Migrations.AddCommentsUserQuestionIndex do
  use Ecto.Migration

  def change do
    create unique_index(:comments, [:user_id, :question_id])
  end
end
