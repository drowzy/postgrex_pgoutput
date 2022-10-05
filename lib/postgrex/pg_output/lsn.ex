defmodule Postgrex.PgOutput.Lsn do
  @moduledoc """
  LSN (Log Sequence Number) is a pointer to a location in the WAL.

  Internally, an LSN is a 64-bit integer, representing a byte position in the write-ahead log stream.
  It is printed as two hexadecimal numbers of up to 8 digits each, separated by a slash; for example, 16/B374D848.

  This module provides convience functions for working with LSN's received
  through the replication protocol.
  """
  import Postgrex.BinaryUtils
  import Bitwise

  @type t :: {non_neg_integer(), non_neg_integer()} | binary()

  @spec decode(binary()) :: t()
  def decode(<<xlog_file::int32(), xlog_offset::int32()>>), do: {xlog_file, xlog_offset}

  @spec decode_string(binary()) :: t()
  def decode_string(lsn_string) do
    with [file_id, offset] <- String.split(lsn_string, "/", trim: true),
         {file_id, ""} when file_id >= 0 <- Integer.parse(file_id, 16),
         {offset, ""} when offset >= 0 <- Integer.parse(offset, 16) do
      {file_id, offset}
    end
  end

  @spec encode(t()) :: binary()
  def encode({xlog_file, xlog_offset}) do
    <<xlog_file::int32(), xlog_offset::int32()>>
  end

  @spec encode_int64(t()) :: integer()
  def encode_int64({xlog_file, xlog_offset}) do
    <<lsn::int64()>> = <<xlog_file::int32(), xlog_offset::int32()>>
    lsn
  end

  @spec encode_string(t()) :: binary()
  def encode_string({xlog_file, xlog_offset}) do
    i = xlog_file <<< 32 ||| xlog_offset
    <<xf::32, xo::32>> = <<i::64>>
    Integer.to_string(xf, 16) <> "/" <> Integer.to_string(xo, 16)
  end
end
