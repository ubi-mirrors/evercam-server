defmodule Country do
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.Repo

  @required_fields ~w(name iso3166_a2)
  @optional_fields ~w()

  schema "countries" do
    has_many :users, User

    field :iso3166_a2, :string
    field :name, :string
  end

  def by_iso3166(country_id) do
    Country
    |> where(iso3166_a2: ^country_id)
    |> Repo.one
  end

  def get_by_code(country_id) when country_id in [nil, ""] do
    {:error, nil}
  end
  def get_by_code(country_id) do
    case Repo.get_by(Country, iso3166_a2: country_id) do
      nil -> {:error, nil}
      country -> {:ok, country}
    end
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:iso3166_a2, [name: :country_code_unique_index])
  end
end
