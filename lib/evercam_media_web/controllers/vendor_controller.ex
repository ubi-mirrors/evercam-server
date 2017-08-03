defmodule EvercamMediaWeb.VendorController do
  use EvercamMedia.Web, :controller
  alias EvercamMediaWeb.VendorView
  alias EvercamMediaWeb.ErrorView

  def show(conn, %{"id" => exid}) do
    case Vendor.by_exid(exid) do
      nil ->
        conn
        |> put_status(404)
        |> render(ErrorView, "error.json", %{message: "Vendor not found."})
      vendor ->
        conn
        |> render(VendorView, "show.json", %{vendor: vendor})
    end
  end

  def index(conn, params) do
    vendors =
      Vendor
      |> Vendor.with_exid_if_given(params["id"])
      |> Vendor.with_name_if_given(params["name"])
      |> Vendor.with_known_macs_if_given(params["mac"])
      |> Vendor.get_all

    conn
    |> render(VendorView, "index.json", %{vendors: vendors})
  end
end
