defmodule MetaData do
  use EvercamMediaWeb, :model
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

  def by_camera(camera_id, action \\ "rtmp") do
    MetaData
    |> where(camera_id: ^camera_id)
    |> where(action: ^action)
    |> Repo.one
  end

  def insert_meta(params) do
    meta_changeset = changeset(%MetaData{}, params)
    Repo.insert(meta_changeset)
  end

  def update_requesters(nil, _), do: :noop
  def update_requesters(meta_data, requester) do
    extra = meta_data |> Map.get(:extra)
    case String.contains?(extra["requester"], requester) do
      false ->
        extra = extra |> Map.put(:requester, "#{extra["requester"]}, #{requester}")
        meta_params = %{extra: extra}
        changeset(meta_data, meta_params)
        |> Repo.update
      _ -> :noop
    end
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

  def delete_by_camera_and_action(camera_id, action) do
    MetaData
    |> where(camera_id: ^camera_id)
    |> where(action: ^action)
    |> Repo.delete_all
  end

  def delete_all do
    MetaData
    |> Repo.delete_all
  end

  def required_fields do
    @required_fields |> Enum.map(fn(field) -> String.to_atom(field) end)
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(required_fields())
  end
end
