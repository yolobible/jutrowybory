defmodule Jutrowybory.Repo.Migrations.CreateSurveyTables do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :string
      add :role, :string, null: false, default: "obywatel"
    end

    create unique_index(:users, [:username])

    create table(:topics) do
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:topics, [:name])

    create table(:questions) do
      add :text, :text, null: false
      add :position, :integer, null: false, default: 0
      add :active, :boolean, null: false, default: true
      add :topic_id, references(:topics, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:questions, [:topic_id])

    create table(:answers) do
      add :value, :integer, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :question_id, references(:questions, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:answers, [:user_id, :question_id])
    create index(:answers, [:question_id])

    create table(:comments) do
      add :body, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :question_id, references(:questions, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:comments, [:question_id])
    create index(:comments, [:user_id])

    create table(:comment_votes) do
      add :value, :integer, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :comment_id, references(:comments, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:comment_votes, [:user_id, :comment_id])
    create index(:comment_votes, [:comment_id])
  end
end
