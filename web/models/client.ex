defmodule Client do
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.Repo

  @required_fields ~w(api_id api_key)
  @optional_fields ~w(name callback_uris settings)

  schema "clients" do
    has_many :access_tokens, AccessToken

    field :name, :string
    field :api_id, :string
    field :api_key, :string
    field :callback_uris, {:array, :string}
    field :settings, :string
    timestamps(inserted_at: :created_at, type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def get_by_bearer(token) do
    Client
    |> join(:left, [cl], t in assoc(cl, :access_tokens))
    |> where([_, t], t.request == ^token)
    |> where([_, t], t.is_revoked == false)
    |> where([_, t], t.expires_at > ^Ecto.DateTime.utc)
    |> Repo.one
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:api_id, [name: "ux_clients_exid"])
  end
end
