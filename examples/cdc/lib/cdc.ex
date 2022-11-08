defmodule CDC do
  @moduledoc """
  opts = [
    host: "localhost",
    database: "postgres",
    username: "postgres",
    password: "postgres",
    port: 5432,
  ]

  {:ok, pg} = Postgrex.start_link(opts)

  Postgrex.query!(pg, "INSERT INTO articles (title, description, body) VALUES ('Postgres replication', 'Using logical replication', 'with Elixir!')", [])
  Postgrex.query!(pg, "UPDATE articles SET title = 'changed' where id = 4", [])
  """

  @doc """
  Start the replication connection process and connect to postgres.
  The options that this function accepts are the same as those accepted by
  `Postgrex.start_link/1`, as well as the extra options `:publications`,
  `:slot`, `:reconnect_backoff`, and `:configure`.

  ## Options
    * `:slot` - Controls slot name used in `CREATE_REPLICATION_SLOT` and `START_REPLICATIN_SLOT`. Required.
    * `:publications` - A list of Postgres publications to use when start the replciation connection. Required
  """
  defdelegate start_link(opts), to: __MODULE__.Replication

  @doc """
  Subscribes to the replication stream.

  A message `{:notification, connection_pid, ref, transaction}` will be
  sent to the calling process when a full transactions has been received by the replication connection.

  ## Options
    * `:timeout` - Call timeout (default: `5_000`)
  """
  defdelegate subscribe(pid, opts \\ []), to: __MODULE__.Replication

  @doc """
  Stops subscribing to the replicaion stream by passing the reference returned from
  `subscribe/2`.

  ## Options
    * `:timeout` - Call timeout (default: `5_000`)
  """
  defdelegate unsubscribe(pid, ref, opts \\ []), to: __MODULE__.Replication
end
