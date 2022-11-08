defmodule Postgrex.PgOutput do
  @moduledoc File.read!(Path.join([__DIR__, "../..", "README.md"]))

  @doc """
  Decodes a binary replication message into

  ## Examples

  * Primary keep alive

      import Postgrex.PgOutput.Messages

      msg = <<107, 0, 0, 0, 0, 1, 130, 140, 128, 0, 2, 141, 89, 193, 229, 5, 73, 1>>
      msg_primary_keep_alive(reply: 1) = pka = Postgrex.PgOutput.decode(msg)

  * Xlog data
      import Postgrex.PgOutput.Messages

      msg = <<119, 0, 0, 0, 0, 1, 94, 109, 184, 0, 0, 0, 0, 1, 94, 109, 184, 0, 2, 141, 89, 243, 12,
        106, 120, 66, 0, 0, 0, 0, 40, 218, 86, 184, 0, 2, 116, 137, 36, 88, 241, 171, 0, 6, 166,
        173>>

      msg_xlog_data(data: msg_begin() = begin) = Postgrex.PgOutput.decode(msg)
  """
  @spec decode(binary()) :: term()
  defdelegate decode(msg), to: __MODULE__.Messages

  @doc """
  Decodes a string `value` into an elixir term based on `type`.

  Values in replication messages are always encoded using the text protocol.

  ## Examples

      iex> 1 = Postgrex.PgOutput.decode_value("1", "int4")
      iex> "string" = Postgrex.PgOutput.decode_value("string", "varchar")

      # jsonb & jsonb array requires that :jason is added to deps
      iex> %{"a" => "b"} = Postgrex.PgOutput.decode_value(~s({"a": "b"}), "jsonb")
      iex> [%{"a" => "b"}] = Postgrex.PgOutput.decode_value("{\"{\\\"a\\\": \\\"b\\\"}\"}", "_jsonb")

  """
  @spec decode_value(binary(), atom()) :: term()
  def decode_value(value, type) do
    type_info = __MODULE__.Type.type_info(type)

    __MODULE__.Type.decode(value, type_info)
  end

  @doc """
  Encodes status messages to send to Postgres.

  ## Examples

    import Postgrex.PgOutput.Messages
    <<lsn::64>> = Postgrex.PgOutput.Lsn.encode({0, 1})

    msg =
      msg_standby_status_update(
        wal_recv: lsn + 1,
        wal_flush: lsn + 1,
        wal_apply: lsn + 1,
        system_clock: now(),
        reply: 0
      )

    bin_msg = Postgrex.PgOutput.encode(msg)
  """
  @spec encode(term()) :: binary()
  defdelegate encode(msg), to: __MODULE__.Messages
end
