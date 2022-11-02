defmodule Postgrex.PgOutput.Type do
  @moduledoc false

  # Generates Postgrex.Type info from pg types in types.exs
  # The mix task: postgrex.pg_output.types is used to generate it from
  # a types.json fetched from pg.

  @external_resource pg_types_path = Path.join(__DIR__, "types.exs")

  @json_lib Application.compile_env(:postgrex, :json_library, Jason)
  {types, _} = Code.eval_file(pg_types_exs_path)

  pg_types = for type <- types, do: struct(Postgrex.TypeInfo, type)

  for type = %{oid: oid, type: type_name} <- pg_types do
    def type_info(unquote(type_name)), do: unquote(Macro.escape(type))
    def oid_to_info(unquote(oid)), do: unquote(Macro.escape(type))
  end

  def all_types, do: unquote(Macro.escape(pg_types))

  @json_delim_pattern ~s(\",\")
  @delim_pattern ","
  def decode(nil, _), do: nil

  def decode(<<?{, bin::binary>>, %{send: "array_send", type: <<?_, type::binary>>}) do
    {pattern, unescape} = type_decode_opts(type)

    inner_type = type_info(type)

    decoded_array = decode_json_array(bin, pattern, unescape, [])

    decoded_array
    |> Enum.map(&decode(&1, inner_type))
    |> Enum.reverse()
  end

  for type <- ["varchar", "timestamp", "timestamptz", "uuid", "text"] do
    def decode(data, %{type: unquote(type)}) do
      data
    end
  end

  for type <- ["int2", "int4", "int8"] do
    def decode(data, %{type: unquote(type)}) do
      {int, _} = Integer.parse(data)
      int
    end
  end

  for type <- ["float4", "float8"] do
    def decode(data, %{type: unquote(type)}) do
      {float, _} = Float.parse(data)
      float
    end
  end

  for type <- ["json", "jsonb"] do
    def decode(data, %{type: unquote(type)}) do
      if json_lib = load_jsonlib() do
        json_lib.decode!(data)
      else
        raise "no `:json_library` configured"
      end
    end
  end

  def decode("t", %{type: "bool"}), do: true
  def decode("f", %{type: "bool"}), do: false
  def decode(date, %{type: "date"}), do: Date.from_iso8601!(date)
  def decode(time, %{type: "time"}), do: Time.from_iso8601!(time)

  def decode(value, type) do
    IO.warn(
      "no #{__MODULE__}.decode type implementation: #{inspect(type)} data: #{inspect(value)}"
    )

    value
  end

  def decode_json_array(pg_array, pattern, unescape, acc) do
    case :binary.match(pg_array, pattern) do
      :nomatch ->
        [pg_array |> String.trim_trailing("}") |> unescape.() | acc]

      {pos, _len} ->
        n = byte_size(pattern)
        {value, <<_p::binary-size(n), rest::binary>>} = :erlang.split_binary(pg_array, pos)

        decode_json_array(rest, pattern, unescape, [unescape.(value) | acc])
    end
  end

  defp type_decode_opts(type) when type in ~w(json jsonb),
    do: {@json_delim_pattern, &unescape_json/1}

  defp type_decode_opts(_type), do: {@delim_pattern, &Function.identity/1}

  defp unescape_json(json) do
    json
    |> String.trim(<<?">>)
    |> String.replace("\\", "")
  end

  defp load_jsonlib do
    Code.ensure_loaded?(@json_lib) and @json_lib
  end
end
