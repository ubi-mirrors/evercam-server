defmodule EvercamMedia.Types.JSON do
  @behaviour Ecto.Type

  def type, do: :json

  def cast(term)
      when is_map(term)
        or is_binary(term)
        or is_list(term)
        or is_number(term),
    do: {:ok, term}

  def cast(_), do: :error

  def load(term), do: {:ok, term}

  def dump(term), do: {:ok, term}
end

defmodule EvercamMedia.Types.JSON.Extension do
  alias Postgrex.TypeInfo

  @behaviour Postgrex.Extension

  def init(_), do: :ok
  def init(_parameters, opts),
    do: Keyword.fetch!(opts, :library)

  def matching(_library),
    do: [type: "json", type: "jsonb"]

  def format(_library),
    do: :binary

  def encode(_), do: :ok
  def encode(%TypeInfo{type: "json"}, map, _state, library),
    do: library.encode!(map)
  def encode(%TypeInfo{type: "jsonb"}, map, _state, library),
    do: <<1, library.encode!(map)::binary>>

  def decode(_), do: :ok
  def decode(%TypeInfo{type: "json"}, json, _state, library),
    do: library.decode!(json)
  def decode(%TypeInfo{type: "jsonb"}, <<1, json::binary>>, _state, library),
    do: library.decode!(json)
end
