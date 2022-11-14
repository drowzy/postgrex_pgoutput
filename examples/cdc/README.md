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

{:notification, #PID<0.299.0>, #Reference<0.3286530408.2501115911.213621>,
 %CDC.Tx{
   timestamp: ~U[2022-11-14 11:59:47Z],
   xid: 1462,
   lsn: {0, 26530432},
   end_lsn: nil,
   relations: %{
     16386 => {:msg_relation, 16386, "public", "articles", :default,
      [
        {:column, [:key], "id", "int4", -1},
        {:column, [], "title", "text", -1},
        {:column, [], "description", "text", -1},
        {:column, [], "body", "text", -1}
      ]}
   },
   operations: [
     %CDC.Tx.Operation{
       type: :insert,
       schema: [
         %{flags: [:key], modifier: -1, name: "id", type: "int4"},
         %{flags: [], modifier: -1, name: "title", type: "text"},
         %{flags: [], modifier: -1, name: "description", type: "text"},
         %{flags: [], modifier: -1, name: "body", type: "text"}
       ],
       namespace: "public",
       table: "articles",
       record: %{
         "body" => "with Elixir!",
         "description" => "Using logical replication",
         "id" => 9,
         "title" => "Postgres replication"
       },
       old_record: %{},
       timestamp: nil
     }
   ],
   state: :begin,
   decode: true
 }}
```

