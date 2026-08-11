defmodule Jutrowybory.Survey.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string

    belongs_to :user, Jutrowybory.Accounts.User
    belongs_to :question, Jutrowybory.Survey.Question
    has_many :votes, Jutrowybory.Survey.CommentVote

    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :user_id, :question_id])
    |> validate_required([:body, :user_id, :question_id])
    |> validate_length(:body, min: 1, max: 2000)
    |> unique_constraint([:user_id, :question_id],
      message: "możesz dodać tylko jeden komentarz pod tym pytaniem"
    )
  end
end
