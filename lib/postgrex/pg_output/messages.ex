defmodule Postgrex.PgOutput.Messages do
  @moduledoc """
  Protocol overview: https://www.postgresql.org/docs/12/protocol-replication.html
  Replication protocol messages https://www.postgresql.org/docs/14/protocol-logicalrep-message-formats.html
  """
  import Postgrex.BinaryUtils
  import Record, only: [defrecord: 2]

  alias Postgrex.PgOutput.{Type, Lsn}

  @pg_epoch DateTime.from_iso8601("2000-01-01T00:00:00Z")
  @epoch DateTime.to_unix(~U[2000-01-01 00:00:00Z], :microsecond)

  defrecord :msg_xlog_data, [:start_lsn, :end_lsn, :system_clock, :data]
  defrecord :msg_primary_keep_alive, [:server_wal, :system_clock, :reply]

  defrecord :msg_standby_status_update, [
    :wal_recv,
    :wal_flush,
    :wal_apply,
    :system_clock,
    :reply
  ]

  defrecord :msg_begin, [:lsn, :timestamp, :xid]
  defrecord :msg_commit, [:flags, :lsn, :end_lsn, :timestamp]
  defrecord :msg_origin, [:lsn, :name]
  defrecord :msg_relation, [:id, :namespace, :name, :replica_identity, :columns]
  defrecord :msg_insert, [:relation_id, :data]
  defrecord :msg_update, [:relation_id, :change_data, :old_data, :change_type]
  defrecord :msg_delete, [:relation_id, :old_data, :change_type]
  defrecord :msg_truncate, [:relation_ids, :opts]
  defrecord :msg_type, [:id, :namespace, :name]
  defrecord :msg_empty, []
  defrecord :column, [:flags, :name, :type, :modifier]

  def now, do: System.os_time(:microsecond) - @epoch

  def encode(
        msg_standby_status_update(
          wal_recv: wal_recv,
          wal_flush: wal_flush,
          wal_apply: wal_apply,
          system_clock: clock,
          reply: reply
        )
      ) do
    <<?r, wal_recv::int64(), wal_flush::int64(), wal_apply::int64(), clock::int64(), reply>>
  end

  def decode(<<?w, wal_start::binary-8, wal_end::binary-8, clock::int64(), data::binary>>) do
    msg_xlog_data(
      start_lsn: Lsn.decode(wal_start),
      end_lsn: Lsn.decode(wal_end),
      system_clock: decode_pg_ts(clock),
      data: decode(data)
    )
  end

  def decode(<<?k, server_wal::binary-8, clock::int64(), reply>>) do
    msg_primary_keep_alive(
      server_wal: Lsn.decode(server_wal),
      system_clock: decode_pg_ts(clock),
      reply: reply
    )
  end

  def decode(<<?B, lsn::binary-8, ts::int64(), xid::int32()>>) do
    msg_begin(lsn: Lsn.decode(lsn), timestamp: decode_pg_ts(ts), xid: xid)
  end

  # flags are unused in postgres and should be 0
  def decode(<<?C, _flag::int8(), lsn::binary-8, end_lsn::binary-8, ts::int64()>>) do
    msg_commit(
      flags: [],
      lsn: Lsn.decode(lsn),
      end_lsn: Lsn.decode(end_lsn),
      timestamp: decode_pg_ts(ts)
    )
  end

  def decode(<<?O, lsn::binary-8, name::binary>>) do
    msg_origin(lsn: Lsn.decode(lsn), name: name)
  end

  def decode(<<?R, id::int32(), rest::binary>>) do
    {namespace, rest} = decode_string(rest)
    {name, rest} = decode_string(rest)
    <<replica_identity::int8(), _nbr_columns::int16(), columns::binary>> = rest

    msg_relation(
      id: id,
      namespace: namespace,
      name: name,
      replica_identity: decode_replica_id(replica_identity),
      columns: decode_columns(columns)
    )
  end

  def decode(<<?I, relation_id::int32(), ?N, tuple_data::binary>>) do
    {data, _rest} = decode_tuple(tuple_data)
    msg_insert(relation_id: relation_id, data: data)
  end

  # The prescence of `old_data` is dependent on the REPLICA IDENTITY of the table.
  # i.e changes to indices, including PRIMARY KEY is recorded if the REPLICA IDENTITY = INDEX
  #
  # A REPLICA IDENTITY = FULL will yield the entire old record
  # A REPLICA IDENTITY = NOTHING returns no columns for a change but only the new record
  #
  # REPLICA IDENTITY != INDEX | FULL
  def decode(<<?U, relation_id::int32(), ?N, tuple_data::binary>>) do
    {data, _rest} = decode_tuple(tuple_data)

    msg_update(relation_id: relation_id, old_data: [], change_data: data, change_type: :default)
  end

  # REPLICA IDENTITY == INDEX | FULL
  def decode(<<?U, relation_id::int32(), key::binary-1, tuple_data::binary>>)
      when key in [<<?O>>, <<?K>>] do
    {old_change, <<?N, new_data::binary>>} = decode_tuple(tuple_data)
    {new_change, <<>>} = decode_tuple(new_data)

    msg_update(
      relation_id: relation_id,
      old_data: old_change,
      change_data: new_change,
      change_type: decode_change(key)
    )
  end

  # The Delete message may contain either a 'K' message part or an 'O' message part, but never both of them.
  def decode(<<?D, relation_id::int32(), key::binary-1, tuple_data::binary>>)
      when key in [<<?O>>, <<?K>>] do
    {old_change, <<>>} = decode_tuple(tuple_data)

    msg_delete(
      relation_id: relation_id,
      old_data: old_change,
      change_type: decode_change(key)
    )
  end

  def decode(<<?T, _nbr_relations::int32(), flag::int8(), rest::binary>>) do
    opts =
      case flag do
        0 -> :none
        1 -> :cascade
        2 -> :restart_identity
      end

    relation_ids = for <<relation_id::int32() <- rest>>, do: relation_id

    msg_truncate(
      opts: opts,
      relation_ids: relation_ids
    )
  end

  def decode(<<?Y, id::int32(), data::binary>>) do
    {namespace, rest} = decode_string(data)
    {name, <<>>} = decode_string(rest)

    msg_type(id: id, namespace: namespace, name: name)
  end

  def decode(<<>>), do: msg_empty()

  defp decode_pg_ts(ts) do
    {:ok, epoch, 0} = @pg_epoch

    DateTime.add(epoch, ts, :microsecond)
  end

  defp decode_columns(binary, accumulator \\ [])
  defp decode_columns(<<>>, accumulator), do: Enum.reverse(accumulator)

  defp decode_columns(<<flags::int8(), rest::binary>>, accumulator) do
    {name, rest} = decode_string(rest)
    <<data_type_id::int32(), modifier::int32(), columns::binary>> = rest

    decoded_flags =
      case flags do
        1 -> [:key]
        _ -> []
      end

    column =
      column(
        name: name,
        flags: decoded_flags,
        type: Type.oid_to_info(data_type_id).typname,
        modifier: modifier
      )

    decode_columns(columns, [column | accumulator])
  end

  defp decode_tuple(<<nbr_columns::int16(), data::binary>>) do
    decode_data(data, nbr_columns, [])
  end

  defp decode_data(bin, 0, acc) do
    {Enum.reverse(acc), bin}
  end

  defp decode_data(<<?n, rest::binary>>, columns_rem, acc) do
    decode_data(rest, columns_rem - 1, [nil | acc])
  end

  # TOASTed value, actual value is not sent
  defp decode_data(<<?u, rest::binary>>, columns_rem, acc) do
    decode_data(rest, columns_rem - 1, [:toast | acc])
  end

  defp decode_data(<<?t, column_length::int32(), tuple::binary>>, columns_rem, acc) do
    size = byte_size(tuple)
    data = :binary.part(tuple, {0, column_length})
    rest = :binary.part(tuple, {size, -(size - column_length)})

    decode_data(rest, columns_rem - 1, [data | acc])
  end

  defp decode_string(bin) do
    {pos, 1} = :binary.match(bin, <<0>>)
    {string, <<0, rest::binary>>} = :erlang.split_binary(bin, pos)
    {string, rest}
  end

  defp decode_change(<<?K>>), do: :index
  defp decode_change(<<?O>>), do: :full
  defp decode_replica_id(?d), do: :default
  defp decode_replica_id(?n), do: :nothing
  defp decode_replica_id(?f), do: :all_columns
  defp decode_replica_id(?i), do: :index
end
