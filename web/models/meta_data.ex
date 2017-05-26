defmodule MetaData do
  use EvercamMedia.Web, :model
  alias EvercamMedia.Repo
  import Ecto.Query

  @required_fields ~w(action)
  @optional_fields ~w(camera_id user_id process_id extra)

  schema "meta_datas" do
    belongs_to :camera, Camera
    belongs_to :user, User

    field :action, :string
    field :process_id, :integer
    field :extra, EvercamMedia.Types.JSON
    timestamps(type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def insert_meta(params) do
    meta_changeset = changeset(%MetaData{}, params)
    Repo.insert(meta_changeset)
  end

  def delete_by_process_id(process_id) do
    MetaData
    |> where(process_id: ^process_id)
    |> Repo.delete_all
  end

  def delete_by_camera_id(camera_id) do
    MetaData
    |> where(camera_id: ^camera_id)
    |> Repo.delete_all
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
