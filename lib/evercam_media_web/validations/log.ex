defmodule EvercamMedia.Validation.Log do
  import String, only: [to_integer: 1]

  def validate_params(params) do
    with :ok <- validate(:from, params["from"]),
         :ok <- validate(:to, params["to"]),
         :ok <- validate(:limit, params["limit"]),
         :ok <- validate(:page, params["page"]),
         :ok <- from_less_than_to(params),
         do: :ok
  end

  defp validate(_key, value) when value in [nil, ""], do: :ok
  defp validate(key, value) do
    case Integer.parse(value) do
      {_number, ""} -> :ok
      _ -> invalid(key)
    end
  end

  defp from_less_than_to(params) do
    from = params["from"]
    to = params["to"]

    if present?(from) && present?(to) && less_or_higher?(from, to) do
      {:invalid, "From can't be higher than to."}
    else
      :ok
    end
  end

  defp present?(value) when value in [nil, ""], do: false
  defp present?(_value), do: true

  defp less_or_higher?(from, to) do
    if to_integer(from) > to_integer(to), do: true
  end

  defp invalid(key), do: {:invalid, "The parameter '#{key}' isn't valid."}
end
