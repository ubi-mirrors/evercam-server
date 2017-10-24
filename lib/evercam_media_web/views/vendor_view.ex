defmodule EvercamMediaWeb.VendorView do
  use EvercamMediaWeb, :view

  def render("index.json", %{vendors: vendors}) do
    %{vendors: render_many(vendors, __MODULE__, "vendor.json")}
  end

  def render("show.json", %{vendor: vendor}) do
    %{vendors: render_many([vendor], __MODULE__, "vendor.json")}
  end

  def render("vendor.json", %{vendor: vendor}) do
    %{
      id: vendor.exid,
      name: vendor.name,
      known_macs: vendor.known_macs,
      logo: "https://evercam-public-assets.s3.amazonaws.com/#{vendor.exid}/logo.jpg",
    }
  end
end
