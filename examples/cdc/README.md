# Cdc

CDC (Change Data Capture) with Postgrex

## Usage

* Start postgres

``` elixir
docker-compose up -d
```

* Fetch deps and start
```shell
mix deps.get
iex -S mix
```

* Start a `CDC.Replication` connection and subscribe to the stream.

A message `{:notification, connection_pid, ref, transaction}` will be sent to the calling process when a full transaction has been received by the replication connection.

``` elixir
opts = [
  slot: "articles_slot",
  publications: ["articles_pub"],
  host: "localhost",
  database: "postgres",
  username: "postgres",
  password: "postgres",
  port: 5432,
]

{:ok, pg} = Postgrex.start_link(opts)
{:ok, cdc_pid} = CDC.start_link(opts)
{:ok, ref} = CDC.subscribe(cdc_pid)

Postgrex.query!(pg, """
  INSERT INTO articles (title, description, body)
  VALUES ('Postgres replication', 'Using logical replication', 'with Elixir!')
  """, [])

flush()
```

