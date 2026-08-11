defmodule Jutrowybory.Survey.Answer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "answers" do
    field :value, :integer

    belongs_to :user, Jutrowybory.Accounts.User
    belongs_to :question, Jutrowybory.Survey.Question

    timestamps(type: :utc_datetime)
  end

  def changeset(answer, attrs) do
    answer
    |> cast(attrs, [:value, :user_id, :question_id])
    |> validate_required([:value, :user_id, :question_id])
    |> validate_number(:value, greater_than_or_equal_to: 0, less_than_or_equal_to: 4)
    |> unique_constraint([:user_id, :question_id])
  end
end
