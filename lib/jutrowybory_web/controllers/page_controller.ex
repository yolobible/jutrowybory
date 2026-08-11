defmodule JutrowyboryWeb.PageController do
  use JutrowyboryWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
