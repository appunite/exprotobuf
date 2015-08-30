defmodule Protobuf do
  alias Protobuf.Parser
  alias Protobuf.Builder
  alias Protobuf.Config
  alias Protobuf.ConfigError
  alias Protobuf.Field
  alias Protobuf.Utils

  defmacro __using__(opts) do
    namespace = __CALLER__.module

    config = case opts do
      << schema :: binary >> ->
        %Config{namespace: namespace, schema: schema}
      [<< schema :: binary >>, only: only] ->
        %Config{namespace: namespace, schema: schema, only: parse_only(only, __CALLER__)}
      [<< schema :: binary >>, inject: true] ->
        only = namespace |> Module.split |> Enum.join(".") |> String.to_atom
        %Config{namespace: namespace, schema: schema, only: [only], inject: true}
      [<< schema :: binary >>, only: only, inject: true] ->
        types = parse_only(only, __CALLER__)
        case types do
          []       -> raise ConfigError, error: "You must specify a type using :only when combined with inject: true"
          [_type]  -> %Config{namespace: namespace, schema: schema, only: types, inject: true}
        end
      from: file ->
        %Config{namespace: namespace, schema: read_file(file, __CALLER__), from_file: file}
      [from: file, only: only] ->
        %Config{namespace: namespace, schema: read_file(file, __CALLER__), only: parse_only(only, __CALLER__), from_file: file}
      [from: file, inject: true] ->
        %Config{namespace: namespace, schema: read_file(file, __CALLER__), only: [namespace], inject: true, from_file: file}
      [from: file, only: only, inject: true] ->
        types = parse_only(only, __CALLER__)
        case types do
          []       -> raise ConfigError, error: "You must specify a type using :only when combined with inject: true"
          [_type]  -> %Config{namespace: namespace, schema: read_file(file, __CALLER__), only: types, inject: true, from_file: file}
        end

      # FIXME:
      # Duplicate all options with include_package because I don't know how else to do this. This needs to be refactored due to exponential branching
      [<< schema :: binary >>, include_package: include_package] ->
        %Config{namespace: namespace, schema: schema, include_package: include_package}
      [<< schema :: binary >>, only: only, include_package: include_package] ->
        %Config{namespace: namespace, schema: schema, only: parse_only(only, __CALLER__), include_package: include_package}
      [<< schema :: binary >>, inject: true, include_package: include_package] ->
        only = namespace |> Module.split |> Enum.join(".") |> String.to_atom
        %Config{namespace: namespace, schema: schema, only: [only], inject: true, include_package: include_package}
      [<< schema :: binary >>, only: only, inject: true, include_package: include_package] ->
        types = parse_only(only, __CALLER__)
        case types do
          []       -> raise ConfigError, error: "You must specify a type using :only when combined with inject: true"
          [_type]  -> %Config{namespace: namespace, schema: schema, only: types, inject: true, include_package: include_package}
        end
      from: file, include_package: include_package ->
        %Config{namespace: namespace, schema: read_file(file, __CALLER__), from_file: file, include_package: include_package}
      [from: file, only: only, include_package: include_package] ->
        %Config{namespace: namespace, schema: read_file(file, __CALLER__), only: parse_only(only, __CALLER__), from_file: file, include_package: include_package}
      [from: file, inject: true, include_package: include_package] ->
        %Config{namespace: namespace, schema: read_file(file, __CALLER__), only: [namespace], inject: true, from_file: file, include_package: include_package}
      [from: file, only: only, inject: true, include_package: include_package] ->
        types = parse_only(only, __CALLER__)
        case types do
          []       -> raise ConfigError, error: "You must specify a type using :only when combined with inject: true"
          [_type]  -> %Config{namespace: namespace, schema: read_file(file, __CALLER__), only: types, inject: true, from_file: file, include_package: include_package}
        end
    end

    config |> parse(__CALLER__) |> Builder.define(config)
  end

  # Read the file passed to :from
  defp read_file(file, caller) do
    {file, []} = Code.eval_quoted(file, [], caller)
    File.read!(file)
  end

  # Read the type or list of types to extract from the schema
  defp parse_only(only, caller) do
    {types, []} = Code.eval_quoted(only, [], caller)
    case types do
      types when is_list(types) -> types
      types when types == nil   -> []
      _                         -> [types]
    end
  end

  # Parse and fix namespaces of parsed types
  defp parse(%Config{namespace: ns, schema: schema, inject: inject, from_file: nil, include_package: include_package}, _) do
    Parser.parse!(schema) |> namespace_types(ns, inject, include_package)
  end
  defp parse(%Config{namespace: ns, schema: schema, inject: inject, from_file: file, include_package: include_package}, caller) do
    {path, _} = Code.eval_quoted(file, [], caller)
    path      = Path.expand(path) |> Path.dirname
    opts      = [imports: [path]]
    Parser.parse!(schema, opts) |> namespace_types(ns, inject, include_package)
  end

  # Find the package namespace
  defp detect_package(parsed) do
    parsed |> Enum.find_value(fn(row) ->
      case row do
        {:package, package} -> package
        _ -> false
      end
    end)
  end

  defp namespace_types(parsed, ns, inject, include_package) do
    # Apply namespace to top-level types
    detect_package(parsed) |> namespace_types(parsed, ns, inject, include_package)
  end

  # Apply namespace to top-level types
  defp namespace_types(package, parsed, ns, inject, include_package) do
    for {{type, name}, fields} <- parsed do
      if inject do
        {{type, :"#{name |> normalize_name}"}, namespace_fields(type, fields, ns)}
      else
        if package && include_package do
          {{type, :"#{ns}.#{package}.#{name |> normalize_name}"}, namespace_fields(type, fields, ns)}
        else
          {{type, :"#{ns}.#{name |> normalize_name}"}, namespace_fields(type, fields, ns)}
        end
      end
    end
  end

  # Apply namespace to nested types
  defp namespace_fields(:msg, fields, ns), do: Enum.map(fields, &namespace_fields(&1, ns))
  defp namespace_fields(_, fields, _),     do: fields
  defp namespace_fields(field, ns) when not is_map(field) do
    field |> Utils.convert_from_record(Field) |> namespace_fields(ns)
  end
  defp namespace_fields(%Field{type: {type, name}} = field, ns) do
    %{field | :type => {type, :"#{ns}.#{name |> normalize_name}"}}
  end
  defp namespace_fields(%Field{} = field, _ns) do
    field
  end

  # Normalizes module names by ensuring they are cased correctly
  # (respects camel-case and nested modules)
  defp normalize_name(name) do
    name
    |> Atom.to_string
    |> String.split(".", parts: :infinity)
    |> Enum.map(fn(x) -> String.split_at(x, 1) end)
    |> Enum.map(fn({first, remainder}) -> String.upcase(first) <> remainder end)
    |> Enum.join(".")
    |> String.to_atom
  end
end
