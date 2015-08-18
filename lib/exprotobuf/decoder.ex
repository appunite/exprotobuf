defmodule Protobuf.Decoder do
  use Bitwise, only_operators: true
  alias Protobuf.Field
  alias Protobuf.OneofField
  alias Protobuf.Utils

  # Decode with record/module
  def decode(bytes, module) do
    defs = for {{type, mod}, fields} <- module.defs, into: [] do
      case type do
        :msg  -> {{:msg, mod}, Enum.map(fields, fn field -> 
          case field do
            %Protobuf.Field{} -> field |> Utils.convert_to_record(Field)
            %Protobuf.OneofField{} -> field |> Utils.convert_to_record(OneofField)            
          end
        end)}
        :enum -> {{:enum, mod}, fields}
        :extensions -> {{:extensions, mod}, fields}
      end
    end
    :gpb.decode_msg(bytes, module, defs)
    |> Utils.convert_from_record(module)
    |> convert_fields
  end

  def varint(bytes) do
    :gpb.decode_varint(bytes)
  end

  defp convert_fields(msg) do
    Enum.reduce(Map.keys(msg), msg, fn
      :__struct__, msg -> msg
      field, %{__struct__: module} = msg ->
        default = Map.get(struct(module), field)
        value   = Map.get(msg, field)
        if value == :undefined do
          Map.put(msg, field, default)
        else
          convert_field(value, msg, module.defs(:field, field))
        end
    end)
  end

  defp convert_field(value, msg, %Field{name: field, type: type, occurrence: occurrence}) do
    case {occurrence, type} do
      {:repeated, _} ->
        value = for v <- value, do: convert_value(type, v)
        Map.put(msg, field, value)
      {_, :string}   ->
        Map.put(msg, field, convert_value(type, value))
      {_, {:msg, _}} ->
        Map.put(msg, field, convert_value(type, value))
      _ ->
        msg
    end
  end
  
  defp convert_field(value, msg, %OneofField{name: field}) do
    cond do
      is_map(elem(value,1)) -> {elem(value,0), convert_fields(elem(value,1))}
      true -> msg
    end
  end

  defp convert_value(:string, value),   do: :unicode.characters_to_binary(value)
  defp convert_value({:msg, _}, value), do: value |> Utils.convert_from_record(elem(value, 0)) |> convert_fields
  defp convert_value(_, value),         do: value
end
