defmodule EvercamMediaWeb.VendorModelController do
  use EvercamMedia.Web, :controller
  alias EvercamMediaWeb.VendorModelView
  import String, only: [to_integer: 1]

  @default_limit 25

  def index(conn, params) do
    with {:ok, vendor} <- vendor_exists(conn, params["vendor_id"])
    do
      limit = get_limit(params["limit"])
      page = get_page(params["page"])

      models =
        VendorModel
        |> VendorModel.check_vendor_in_query(vendor)
        |> VendorModel.check_name_in_query(params["name"])
        |> VendorModel.get_all

      total_models = Enum.count(models)
      total_pages = Float.floor(total_models / limit)
      returned_models = Enum.slice(models, page * limit, limit)

      conn
      |> render(VendorModelView, "index.json", %{vendor_models: returned_models, pages: total_pages, records: total_models})
    end
  end

  def show(conn, %{"id" => exid}) do
    case VendorModel.by_exid(exid) do
      nil ->
        render_error(conn, 404, "Model Not found.")
      model ->
        conn
        |> render(VendorModelView, "show.json", %{vendor_model: model})
    end
  end

  defp get_limit(limit) when limit in [nil, ""], do: @default_limit
  defp get_limit(limit), do: if to_integer(limit) < 1, do: @default_limit, else: to_integer(limit)

  defp get_page(page) when page in [nil, ""], do: 0
  defp get_page(page), do: if to_integer(page) < 0, do: 0, else: to_integer(page)

  defp vendor_exists(_conn, vendor_id) when vendor_id in [nil, ""], do: {:ok, nil}
  defp vendor_exists(conn, vendor_id) do
    case Vendor.by_exid_without_associations(vendor_id) do
      nil -> render_error(conn, 404, "Vendor not found.")
      %Vendor{} = vendor -> {:ok, vendor}
    end
  end
end
