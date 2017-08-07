defmodule EvercamMediaWeb.PageController do
  use EvercamMediaWeb, :controller

  def index(conn, _params) do
    redirect conn, external: "http://www.evercam.io"
  end
end
