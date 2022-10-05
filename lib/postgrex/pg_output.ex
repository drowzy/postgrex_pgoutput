defmodule Postgrex.PgOutput do
  @moduledoc """
  Encodes / decodes Postgres pgoutput messages

  ## Usage

  """
  @spec decode(binary()) :: term()
  defdelegate decode(msg), to: __MODULE__.Messages

  @spec encode(binary()) :: term()
  defdelegate encode(msg), to: __MODULE__.Messages
end
