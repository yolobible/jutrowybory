defmodule Jutrowybory.Survey.Question do
  use Ecto.Schema
  import Ecto.Changeset

  schema "questions" do
    field :text, :string
    field :position, :integer, default: 0
    field :active, :boolean, default: true

    belongs_to :topic, Jutrowybory.Survey.Topic
    has_many :answers, Jutrowybory.Survey.Answer
    has_many :comments, Jutrowybory.Survey.Comment

    timestamps(type: :utc_datetime)
  end

  def changeset(question, attrs) do
    question
    |> cast(attrs, [:text, :position, :active, :topic_id])
    |> validate_required([:text, :topic_id])
    |> validate_length(:text, min: 5, max: 1000)
    |> assoc_constraint(:topic)
  end
end
