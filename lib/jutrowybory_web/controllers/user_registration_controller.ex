defmodule JutrowyboryWeb.UserRegistrationController do
  use JutrowyboryWeb, :controller

  alias Jutrowybory.Accounts
  alias Jutrowybory.Accounts.User
  alias JutrowyboryWeb.UserAuth

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Konto utworzone. Witaj, #{user.username}!")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
