defmodule Protobuf.Utils do
  @moduledoc false
  alias Protobuf.OneofField
  alias Protobuf.Field

  def convert_to_record(map, module) do
    convert_to_record(map, module, record_name(module))
  end

  defp record_name(OneofField), do: :gpb_oneof
  defp record_name(Field), do: :field
  defp record_name(type), do: type

  defp convert_to_record(map, OneofField = module, record_name) do
    module.record
    |> Enum.reduce([record_name], fn {key, default}, acc ->
      value = Map.get(map, key, default)
      cond do
        is_list(value) ->
          [Enum.map(value, &convert_to_record(&1, Field)) | acc]
        true ->
          [value|acc]
      end
    end)
    |> Enum.reverse
    |> List.to_tuple
  end

  defp convert_to_record(map, module, record_name) do
    module.record
    |> Enum.reduce([record_name], fn {key, default}, acc ->
      value = Map.get(map, key, default)
      [value|acc]
    end)
    |> Enum.reverse
    |> List.to_tuple
  end

  def convert_from_record(rec, module) do
    map = struct(module)

    module.record
    |> Enum.with_index
    |> Enum.reduce(map, fn {{key, _default}, idx}, acc ->
        # rec has the extra element when defines the record type
        value = elem(rec, idx + 1)
        Map.put(acc, key, value)
    end)
  end
end
