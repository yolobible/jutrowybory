defmodule Jutrowybory.Accounts.UserNotifier do
  @moduledoc """
  Aplikacja nie wysyła e-maili (brak mailera) — powiadomienia
  są logowane. Logowanie odbywa się hasłem.
  """

  require Logger

  alias Jutrowybory.Accounts.User

  defp deliver(recipient, subject, body) do
    Logger.info("""
    E-mail (nie wysłano — brak mailera):
    Do: #{recipient}
    Temat: #{subject}
    #{body}
    """)

    {:ok, %{to: recipient, subject: subject, text_body: body}}
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
