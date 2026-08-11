defmodule Jutrowybory.Survey.CommentVote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comment_votes" do
    field :value, :integer

    belongs_to :user, Jutrowybory.Accounts.User
    belongs_to :comment, Jutrowybory.Survey.Comment

    timestamps(type: :utc_datetime)
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:value, :user_id, :comment_id])
    |> validate_required([:value, :user_id, :comment_id])
    |> validate_inclusion(:value, [-1, 1])
    |> unique_constraint([:user_id, :comment_id])
  end
end
