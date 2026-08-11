defmodule Jutrowybory.Repo do
  use Ecto.Repo,
    otp_app: :jutrowybory,
    adapter: Ecto.Adapters.Postgres
end
