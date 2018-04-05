defmodule EvercamMediaWeb.VendorController do
  use EvercamMediaWeb, :controller
  use PhoenixSwagger
  alias EvercamMediaWeb.VendorView
  alias EvercamMediaWeb.ErrorView

  swagger_path :show do
    get "/vendors/{id}"
    summary "Returns available information for the specified vendor."
    parameters do
      id :path, :string, "The ID of the vendor being requested."
    end
    tag "Vendors"
    response 200, "Success"
    response 404, "Not found"
  end

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

  swagger_path :index do
    get "/vendors"
    summary "Returns all vendors."
    tag "Vendors"
    response 200, "Success"
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
