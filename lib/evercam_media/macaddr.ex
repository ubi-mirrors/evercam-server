defmodule EvercamMedia.Types.MACADDR do
  @behaviour Ecto.Type

  def type, do: :macaddr

  def cast(nil), do: :error
  def cast(mac), do: {:ok, to_string(mac)}

  def load(mac), do: {:ok, to_string(mac)}

  def dump(mac), do: {:ok, to_string(mac)}
end

defmodule EvercamMedia.Types.MACADDR.Extension do
  alias Postgrex.TypeInfo

  @behaviour Postgrex.Extension

  def init(parameters, _opts), do: parameters

  def matching(_library), do: [type: "macaddr"]

  def format(_), do: :text

  def encode(%TypeInfo{type: "macaddr"}, binary, _types, _opts), do: binary

  def decode(%TypeInfo{type: "macaddr"}, binary, _types, _opts), do: binary
end
