defmodule VendorModel do
  use EvercamMediaWeb, :model
  import Ecto.Query
  alias EvercamMedia.Repo
  alias EvercamMedia.Util

  schema "vendor_models" do
    belongs_to :vendor, Vendor, foreign_key: :vendor_id
    has_many :cameras, Camera

    field :exid, :string
    field :name, :string
    field :username, :string
    field :password, :string
    field :jpg_url, :string
    field :h264_url, :string
    field :mjpg_url, :string
    field :shape, :string
    field :resolution, :string
    field :official_url, :string
    field :more_info, :string
    field :audio_url, :string
    field :poe, :boolean
    field :wifi, :boolean
    field :upnp, :boolean
    field :ptz, :boolean
    field :infrared, :boolean
    field :varifocal, :boolean
    field :sd_card, :boolean
    field :audio_io, :boolean
    field :discontinued, :boolean
    field :onvif, :boolean
    field :psia, :boolean
    field :channel, :integer
    field :config, EvercamMedia.Types.JSON
  end

  def by_exid(exid) do
    VendorModel
    |> where(exid: ^String.downcase(exid))
    |> preload(:vendor)
    |> Repo.one
  end

  def get_vendor_default_model(nil), do: nil
  def get_vendor_default_model(vendor) do
    VendorModel
    |> where(vendor_id: ^vendor.id)
    |> where(name: "Default")
    |> Repo.one
  end

  def get_model(action, vendor_exid, model_exid) do
    vendor_exid = String.downcase("#{vendor_exid}")
    model_exid = String.downcase("#{model_exid}")

    case {vendor_exid, model_exid} do
      {"", ""} ->
        if action == "update", do: nil, else: by_exid("other_default")
      {"", model_exid} ->
        by_exid(model_exid)
      {vendor_exid, ""} ->
        vendor_exid
        |> Vendor.by_exid
        |> get_vendor_default_model
      {vendor_exid, model_exid} ->
        model = by_exid(model_exid)
        if model, do: model, else: get_model(action, vendor_exid, "")
    end
  end

  def get_models_count(query) do
    query
    |> select([vm], count(vm.id))
    |> Repo.all
    |> List.first
  end

  def get_all(query \\ VendorModel) do
    query
    |> order_by([vm], asc: vm.name)
    |> preload(:vendor)
    |> Repo.all
  end

  def check_vendor_in_query(query, vendor) when vendor in [nil, ""], do: query
  def check_vendor_in_query(query, vendor) do
    query
    |> where([vm], vm.vendor_id == ^vendor.id)
  end

  def check_name_in_query(query, name) when name in [nil, ""], do: query
  def check_name_in_query(query, name) do
    query
    |> where([vm], like(fragment("lower(?)", vm.name), ^("%#{String.downcase(name)}%")))
  end

  def get_channel(camera, channel) when channel in ["", nil] do
    camera.vendor_model.jpg_url
    |> String.downcase
    |> String.split("/channels/")
    |> List.last
    |> String.split("/")
    |> List.first
  end
  def get_channel(_camera, channel), do: channel

  def get_url(model, attr \\ "jpg") do
    Util.deep_get(model.config, ["snapshots", "#{attr}"], "")
  end

  def get_image_url(model_full, type \\ "original") do
    "https://evercam-public-assets.s3.amazonaws.com/#{model_full.vendor.exid}/#{model_full.exid}/#{type}.jpg"
  end
end
