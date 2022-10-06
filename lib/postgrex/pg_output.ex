defmodule Postgrex.PgOutput do
  @moduledoc """
  Encodes / decodes Postgres pgoutput messages

  ## Usage
  """

  @doc """
  """
  @spec decode(binary()) :: term()
  defdelegate decode(msg), to: __MODULE__.Messages

  @doc """
  """
  @spec decode_type(binary(), atom()) :: term()
  defdelegate decode_type(value, type), to: __MODULE__.Type, as: :decode

  @doc """
  """
  @spec encode(binary()) :: term()
  defdelegate encode(msg), to: __MODULE__.Messages
end
