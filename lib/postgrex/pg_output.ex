defmodule Postgrex.PgOutput do
  @moduledoc File.read!(Path.join([__DIR__, "../..", "README.md"]))

  @doc """
  Decodes a binary replication message into

  ## Examples
  """
  @spec decode(binary()) :: term()
  defdelegate decode(msg), to: __MODULE__.Messages

  @doc """
  Decodes binary `value` into an elixir term based on `type`

  ## Examples
  """
  @spec decode_type(binary(), atom()) :: term()
  defdelegate decode_type(value, type), to: __MODULE__.Type, as: :decode

  @doc """
  Encodes a replication message to send to Postgres.

  ## Examples
  """
  @spec encode(term()) :: binary()
  defdelegate encode(msg), to: __MODULE__.Messages
end
