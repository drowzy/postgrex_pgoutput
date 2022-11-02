defmodule Mix.Tasks.Postgrex.PgOutput.Types do
  @moduledoc """
  Generate a `types.exs` from the result of the following query:

        postgres=# \o lib/postgrex/types.json

        postgres=# SELECT row_to_json(r) FROM (SELECT t.oid::INTEGER, t.typname as type, t.typsend as send, t.typreceive as receive, t.typoutput as output, t.typinput as input,
                coalesce(d.typelem, t.typelem)::INTEGER as array_elem, coalesce(r.rngsubtype, 0)::INTEGER as base_type, ARRAY (
            SELECT a.atttypid
            FROM pg_attribute AS a
            WHERE a.attrelid = t.typrelid AND a.attnum > 0 AND NOT a.attisdropped
            ORDER BY a.attnum
        ) as comp_elems
        FROM pg_type AS t
        LEFT JOIN pg_type AS d ON t.typbasetype = d.oid
        LEFT JOIN pg_range AS r ON r.rngtypid = t.oid OR (t.typbasetype <> 0 AND r.rngtypid = t.typbasetype)
        WHERE (t.typrelid = 0)
        AND (t.typelem = 0 OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type s WHERE s.typrelid != 0 AND s.oid = t.typelem))
        ) as r;

        postgres=# \o

  """

  use Mix.Task
  @shortdoc "Generate types.exs from a types in Postgres"

  @impl true
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [input: :string, output: :string],
        aliases: [i: :input, o: :output]
      )

    input = opts[:input] || "./lib/postgrex/pg_output/types.json"
    output = opts[:output] || "./lib/postgrex/pg_output/types.exs"

    types =
      for line <- File.stream!(input) do
        if jason = Code.ensure_loaded!(Jason) do
          jason.decode!(line, keys: :atoms)
        else
          Mix.raise("`:jason` not loaded")
        end
      end

    IO.inspect(types)
    Mix.shell().info("Generating #{output}")

    write_to_disk(types, input, output)
  end

  defp write_to_disk(types, input, output) do
    now = DateTime.utc_now() |> Map.put(:microsecond, {0, 0}) |> to_string
    content = inspect(types, limit: :infinity)
    IO.inspect(content)

    prelude = """
    # Generated from #{input} at #{now}

    """

    File.write!(output, [prelude | content])
  end
end
