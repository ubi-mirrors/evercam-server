defmodule AccessToken do
  use EvercamMedia.Web, :model
  import Ecto.Changeset
  import Ecto.Query
  alias EvercamMedia.Repo
  alias EvercamMedia.Util

  @required_fields ~w(is_revoked request)
  @optional_fields ~w(grantor_id user_id refresh)

  schema "access_tokens" do
    belongs_to :user, User, foreign_key: :user_id
    belongs_to :client, Client, foreign_key: :client_id
    belongs_to :grantor, User, foreign_key: :grantor_id
    has_many :rights, AccessRight

    field :is_revoked, :boolean, null: false
    field :request, :string, null: false
    field :refresh, :string
    timestamps(inserted_at: :created_at, type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def active_token_id_for(user_id) do
    AccessToken
    |> where([t], t.user_id == ^user_id)
    |> where([t], t.is_revoked == false)
    |> order_by(desc: :created_at)
    |> limit(1)
    |> Repo.one
    |> Util.deep_get([:id], 0)
  end

  def by_request_token(token) do
    AccessToken
    |> where(request: ^token)
    |> preload(:user)
    |> preload(:grantor)
    |> Repo.one
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:request, on: EvercamMedia.Repo)
  end
end
