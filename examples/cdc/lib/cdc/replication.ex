defmodule CDC.Replication do
  use Postgrex.ReplicationConnection

  alias CDC.Protocol

  require Logger

  defstruct [
    :publications,
    :protocol,
    :slot,
    :state,
    subscribers: %{}
  ]

  def start_link(opts) do
    conn_opts = [auto_reconnect: true]
    publications = opts[:publications] || raise ArgumentError, message: "`:publications` missing"
    slot = opts[:slot] || raise ArgumentError, message: "`:slot` missing"

    Postgrex.ReplicationConnection.start_link(
      __MODULE__,
      {slot, publications},
      conn_opts ++ opts
    )
  end

  def subscribe(pid, opts \\ []) do
    Postgrex.ReplicationConnection.call(pid, :subscribe, Keyword.get(opts, :timeout, 5_000))
  end

  def unsubscribe(pid, ref, opts \\ []) do
    Postgrex.ReplicationConnection.call(
      pid,
      {:unsubscribe, ref},
      Keyword.get(opts, :timeout, 5_000)
    )
  end

  @impl true
  def init({slot, pubs}) do
    {:ok,
     %__MODULE__{
       slot: slot,
       publications: pubs,
       protocol: Protocol.new()
     }}
  end

  @impl true
  def handle_connect(%__MODULE__{slot: slot} = state) do
    query = "CREATE_REPLICATION_SLOT #{slot} TEMPORARY LOGICAL pgoutput NOEXPORT_SNAPSHOT"

    Logger.debug("[create slot] query=#{query}")

    {:query, query, %{state | state: :create_slot}}
  end

  @impl true
  def handle_result(
        [%Postgrex.Result{} | _],
        %__MODULE__{state: :create_slot, publications: pubs} = state
      ) do
    opts = [proto_version: 1, publication_names: pubs]

    query = "START_REPLICATION SLOT articles_slot LOGICAL 0/0 #{escape_options(opts)}"

    Logger.debug("[start streaming] query=#{query}")

    {:stream, query, [], %{state | state: :streaming}}
  end

  @impl true
  def handle_data(msg, state) do
    {return_msgs, tx, protocol} = Protocol.handle_message(msg, state.protocol)

    if not is_nil(tx) do
      notify(tx, state.subscribers)
    end

    {:noreply, return_msgs, %{state | protocol: protocol}}
  end

  # Replies must be sent using `reply/2`
  # https://hexdocs.pm/postgrex/Postgrex.ReplicationConnection.html#reply/2
  @impl true
  def handle_call(:subscribe, {pid, _} = from, state) do
    ref = Process.monitor(pid)

    state = put_in(state.subscribers[ref], pid)

    Postgrex.ReplicationConnection.reply(from, {:ok, ref})

    {:noreply, state}
  end

  def handle_call({:unsubscribe, ref}, from, state) do
    {reply, new_state} =
      case state.subscribers do
        %{^ref => _pid} ->
          Process.demonitor(ref, [:flush])

          {_, state} = pop_in(state.subscribers[ref])
          {:ok, state}

        _ ->
          {:error, state}
      end

    from && Postgrex.ReplicationConnection.reply(from, reply)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _}, state) do
    handle_call({:unsubscribe, ref}, nil, state)
  end

  defp notify(tx, subscribers) do
    for {ref, pid} <- subscribers do
      send(pid, {:notification, self(), ref, tx})
    end

    :ok
  end

  defp escape_options([]),
    do: ""

  defp escape_options(opts) do
    parts =
      Enum.map_intersperse(opts, ", ", fn {k, v} -> [Atom.to_string(k), ?\s, escape_string(v)] end)

    [?\s, ?(, parts, ?)]
  end

  defp escape_string(value) do
    [?', :binary.replace(to_string(value), "'", "''", [:global]), ?']
  end
end
