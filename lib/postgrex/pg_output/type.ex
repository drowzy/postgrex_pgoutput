defmodule Postgrex.PgOutput.Type do
  @moduledoc false

  # SELECT row_to_json(r) FROM (SELECT DISTINCT t.oid::INTEGER, t.typname, t.typlen, t.typsend, t.typreceive, t.typoutput, t.typinput,
  # coalesce(d.typelem, t.typelem) as typelem, coalesce(r.rngsubtype, 0) as rngsubtype
  # FROM pg_type AS t
  # LEFT JOIN pg_type AS d ON t.typbasetype = d.oid
  # LEFT JOIN pg_range AS r ON r.rngtypid = t.oid OR (t.typbasetype <> 0 AND r.rngtypid = t.typbasetype)
  # WHERE (t.typrelid = 0)
  # AND (t.typelem = 0 OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type s WHERE s.typrelid != 0 AND s.oid = t.typelem))
  # ) as r;

  @external_resource pg_type_path = Path.join(__DIR__, "type.json")
  @json_lib Application.compile_env(:postgrex, :json_library, Jason)

  pg_types =
    for line <- File.stream!(pg_type_path) do
      line
      |> @json_lib.decode!()
      |> Enum.map(fn
        {"typname" = k, v} ->
          [
            {String.to_atom(k), String.to_atom(v)},
            {String.to_atom(k <> "_str"), v}
          ]

        {k, v} ->
          {String.to_atom(k), v}
      end)
      |> List.flatten()
      |> Map.new()
    end

  for type = %{typname: typname, oid: oid} <- pg_types do
    def type_info(unquote(typname)), do: unquote(Macro.escape(type))
    def oid_to_info(unquote(oid)), do: unquote(Macro.escape(type))
  end

  @json_delim_pattern ~s(\",\")
  @delim_pattern ","
  def decode(nil, _), do: nil

  def decode(<<?{, bin::binary>>, %{typsend: "array_send", typname_str: <<?_, type::binary>>}) do
    {pattern, unescape} = type_decode_opts(type)

    inner_type =
      type
      |> String.to_existing_atom()
      |> type_info()

    decoded_array = decode_json_array(bin, pattern, unescape, [])

    decoded_array
    |> Enum.map(&decode(&1, inner_type))
    |> Enum.reverse()
  end

  for type <- [:varchar, :timestamp, :timestamptz, :uuid, :text] do
    def decode(data, %{typname: unquote(type)}) do
      data
    end
  end

  for type <- [:int2, :int4, :int8] do
    def decode(data, %{typname: unquote(type)}) do
      {int, _} = Integer.parse(data)
      int
    end
  end

  for type <- [:float4, :float8] do
    def decode(data, %{typname: unquote(type)}) do
      {float, _} = Float.parse(data)
      float
    end
  end

  for type <- [:json, :jsonb] do
    def decode(data, %{typname: unquote(type)}) do
      if json_lib = load_jsonlib() do
        json_lib.decode!(data)
      else
        raise "no `:json_library` configured"
      end
    end
  end

  def decode("t", %{typname: :bool}), do: true
  def decode("f", %{typname: :bool}), do: false
  def decode(date, %{typname: :date}), do: Date.from_iso8601!(date)
  def decode(time, %{typname: :time}), do: Time.from_iso8601!(time)

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
