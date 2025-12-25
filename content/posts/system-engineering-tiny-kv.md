+++
title = "Systems Engineering | Tiny KV"
date = 2025-11-04
+++

For the time being, working on The World of Noumenon requires time and thought. All of that is good, but I also want other things in life. One of the things I like is systems thinking. So I thought that perhaps I could build a few projects with Elixir and Rust to cover systems thinking within the context of software engineering.

Today, we will work on a simple key–value store: TinyKV – an in-memory key–value store over TCP

* Concepts to cover: sockets, protocols, concurrency, state, back-pressure.
* Elixir: GenServer + Task.Supervisor + :gen_tcp
* Rust: std::net + std::thread + std::sync

Let’s dive in.

We can execute all the following code by using the raw-dogged technique (if we need libraries).

```elixir
# lib/tiny_kv/application.ex
defmodule TinyKV.Application do
  @moduledoc """
  OTP application entrypoint for TinyKV.

  Starts the supervision tree:

    * `TinyKV.Store` – in-memory key–value store
    * `TinyKV.ConnectionSupervisor` – `Task.Supervisor` for per-connection processes
    * `TinyKV.TCPServer` – TCP listener that accepts and delegates client connections
  """

  use Application

  @impl true
  @spec start :: Supervisor.on_start()
  def start do
    port = Application.get_env(:tiny_kv, :port, 4040)

    children = [
      TinyKV.Store,
      {Task.Supervisor, name: TinyKV.ConnectionSupervisor},
      {TinyKV.TCPServer, port}
    ]

    opts = [strategy: :one_for_one, name: TinyKV.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# lib/tiny_kv/store.ex
defmodule TinyKV.Store do
  @moduledoc """
  In-memory key–value store backed by a `GenServer`.

  Keys and values are stored in a map. All operations are synchronous:

    * `set/2` – store a key–value pair
    * `get/1` – fetch the value for a key
    * `del/1` – delete a key and return its previous value

  Missing keys are represented as the atom `:nil`.
  """

  use GenServer

  alias __MODULE__, as: Store

  @typedoc "Key used in the store. For the TCP protocol we expect strings."
  @type key :: String.t()

  @typedoc "Value stored in the store. Protocol currently treats these as strings."
  @type value :: String.t()

  @typedoc "Internal state of the store: a map of keys to values."
  @type state :: %{optional(key()) => value()}

  @doc """
  Starts the `TinyKV.Store` GenServer.

  By default, the server is registered under the `TinyKV.Store` name
  so that the public API functions can call it directly.

  Accepts standard `GenServer` options, such as `:name`.
  """
  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(opts \\ []),
    do: GenServer.start_link(Store, %{}, Keyword.put_new(opts, :name, Store))

  @doc """
  Sets a key to a given value.

  Returns `:ok` once the value has been stored.
  """
  @spec set(key(), value()) :: :ok
  def set(key, value), do: GenServer.call(Store, {:set, key, value})

  @doc """
  Gets the value associated with the given key.

  Returns the stored value when present, or `:nil` if the key is missing.
  """
  @spec get(key()) :: value() | :nil
  def get(key), do: GenServer.call(Store, {:get, key})

  @doc """
  Deletes the given key from the store.

  Returns the previous value if the key existed, or `:nil` if it did not.
  """
  @spec del(key()) :: value() | :nil
  def del(key), do: GenServer.call(Store, {:del, key})

  @impl true
  @spec init(state()) :: {:ok, state()}
  def init(state), do: {:ok, state}

  @impl true
  @spec handle_call(
          {:set, key(), value()} | {:get, key()} | {:del, key()},
          GenServer.from(),
          state()
        ) ::
          {:reply, :ok | value() | :nil, state()}
  def handle_call({:set, key, value}, _from, state),
    do: {:reply, :ok, Map.put(state, key, value)}

  def handle_call({:get, key}, _from, state),
    do: {:reply, Map.get(state, key, :nil), state}

  def handle_call({:del, key}, _from, state) do
    {value, new_state} = Map.pop(state, key, :nil)
    {:reply, value, new_state}
  end
end

# lib/tiny_kv/tcp_server.ex
defmodule TinyKV.TCPServer do
  @moduledoc """
  TCP listener process for TinyKV.

  This GenServer:

    * Listens on the configured TCP port
    * Accepts incoming client connections
    * Spawns a supervised task for each client, delegating to `TinyKV.Connection`

  Each client connection is handled by `TinyKV.Connection.handle_client/1`
  under the `TinyKV.ConnectionSupervisor` `Task.Supervisor`.
  """

  use GenServer

  alias __MODULE__, as: TCPServer
  require Logger

  @typedoc "Underlying socket used for listening for new connections."
  @type listen_socket :: port()

  @typedoc "State for the TCP server process."
  @type state :: %{socket: listen_socket()}

  @doc """
  Starts the TCP server GenServer.

  The `port` argument is the TCP port on which the server will listen.

  The server is registered under the `TinyKV.TCPServer` name.
  """
  @spec start_link(non_neg_integer()) :: GenServer.on_start()
  def start_link(port), do: GenServer.start_link(TCPServer, port, name: TCPServer)

  @impl true
  @doc """
  Initializes the TCP server.

  This:

    * Binds a listening socket on the provided `port`
    * Logs the listening information
    * Spawns a background task to accept incoming connections in a loop

  The GenServer's state holds the listening socket.
  """
  @spec init(non_neg_integer()) :: {:ok, state()}
  def init(port) do
    {:ok, listen_socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("TinyKV listening on port #{port}")

    # Start the accept loop in a separate task so the GenServer can finish initialization.
    Task.start_link(fn -> accept_loop(listen_socket) end)

    {:ok, %{socket: listen_socket}}
  end

  # Private: Accepts incoming client sockets in a loop and spins up a Task per client.
  @spec accept_loop(listen_socket()) :: :ok | :error
  defp accept_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(TinyKV.ConnectionSupervisor, fn ->
          TinyKV.Connection.handle_client(socket)
        end)

        accept_loop(listen_socket)

      {:error, reason} ->
        Logger.error("accept failed: #{inspect(reason)}")
        :error
    end
  end
end

# lib/tiny_kv/connection.ex
defmodule TinyKV.Connection do
  @moduledoc """
  Handles a single client connection to TinyKV.

  Implements a minimal text-based protocol over TCP:

      SET <key> <value>\\r\\n
      GET <key>\\r\\n
      DEL <key>\\r\\n

  Responses roughly mimic Redis-style conventions:

    * `+OK\\r\\n` – successful `SET`
    * `$<len>\\r\\n<value>\\r\\n` – successful `GET`
    * `$-1\\r\\n` – missing key on `GET`
    * `:1\\r\\n` – key deleted on `DEL`
    * `:0\\r\\n` – key not found on `DEL`
    * `-ERR unknown command\\r\\n` – unsupported input

  Each TCP client is handled in its own process, typically started by
  `TinyKV.TCPServer` under `TinyKV.ConnectionSupervisor`.
  """

  require Logger

  @typedoc "TCP socket for the current client connection."
  @type socket :: port()

  @typedoc "Raw command line received from the client."
  @type raw_command :: String.t()

  @typedoc "Wire-format response string to send back to the client."
  @type response :: String.t()

  @doc """
  Handles the lifecycle of a single TCP client.

  Sends an initial greeting and then enters the receive loop. The loop
  continues until the client closes the connection or an error occurs.

  Returns `:ok` when the connection handling is finished.
  """
  @spec handle_client(socket()) :: :ok
  def handle_client(socket) do
    :gen_tcp.send(socket, "+TinyKV ready\r\n")
    loop(socket)
  end

  # Private: main receive loop.
  #
  # Reads a line from the client, parses and executes the command via
  # `handle_command/1`, sends the response, then recurses. If the client
  # closes the connection or an error occurs, the loop terminates.
  @spec loop(socket()) :: :ok
  defp loop(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        response = handle_command(String.trim(data))
        :gen_tcp.send(socket, response)
        loop(socket)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        Logger.error("socket error: #{inspect(reason)}")
        :ok
    end
  end

  # Private: parses a single command line and performs the corresponding
  # store operation, returning a protocol-level response string.
  @spec handle_command(raw_command()) :: response()
  defp handle_command(line) do
    parts = String.split(line, " ", parts: 3)

    case parts do
      ["SET", key, value] ->
        :ok = TinyKV.Store.set(key, value)
        "+OK\r\n"

      ["GET", key] ->
        case TinyKV.Store.get(key) do
          :nil -> "$-1\r\n"
          value -> "$#{byte_size(value)}\r\n#{value}\r\n"
        end

      ["DEL", key] ->
        case TinyKV.Store.del(key) do
          :nil -> ":0\r\n"
          _ -> ":1\r\n"
        end

      _ ->
        "-ERR unknown command\r\n"
    end
  end
end

{:ok, _} = Supervisor.start_link([%{
      id: TinyKV.Application,
      start: {TinyKV.Application, :start, []}
    }], strategy: :one_for_one)

Process.sleep(:infinity)

```

We can have all that in one file, say tiny.exs, and execute it:

```bash
$ elixir tiny.exs
```

We can then run another terminal session for a telnet client to interact with the server:

```bash
$ telnet localhost 4040

Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
+TinyKV ready
SET foo bar
+OK
GET foo
$3
bar
DEL foo
:1
GET foo
$-1
```

Now, for the rust version, we have:

```rust
//! TinyKV: a tiny in-memory key-value store over TCP using only the Rust standard library.
//!
//! Protocol (very Redis-ish but simplified):
//! - `SET key value`  -> `+OK\r\n`
//! - `GET key`        -> `$<len>\r\n<value>\r\n` or `$-1\r\n` if missing
//! - `DEL key`        -> `:1\r\n` if deleted, `:0\r\n` if not found

use std::{
    collections::HashMap,
    io::{BufRead, BufReader, Write},
    net::{TcpListener, TcpStream},
    sync::{Arc, RwLock},
    thread,
};

/// Shared key-value store type.
///
/// This is:
/// - `HashMap<String, String>` to hold keys and values in memory.
/// - Wrapped in `RwLock` so multiple threads can read concurrently but writes are exclusive.
/// - Wrapped in `Arc` so it can be shared across threads safely and cheaply cloned.
type Store = Arc<RwLock<HashMap<String, String>>>;

/// Entry point for the TinyKV server.
///
/// # Behavior
///
/// - Binds a TCP listener to `127.0.0.1:4040`.
/// - Creates a shared, in-memory key-value store.
/// - For each incoming TCP connection:
///   - Clones a handle to the store.
///   - Spawns a new thread to handle that client.
///
/// The server runs indefinitely until the process is terminated.
///
/// # Errors
///
/// Returns an `std::io::Result<()>` which propagates any I/O errors that
/// occur when binding the port or accepting incoming connections.
fn main() -> std::io::Result<()> {
    let addr = "127.0.0.1:4040";
    let listener = TcpListener::bind(addr)?;
    println!("TinyKV (std) listening on {}", addr);

    // Create the shared, thread-safe store.
    let store: Store = Arc::new(RwLock::new(HashMap::new()));

    // Accept incoming TCP connections in a loop.
    for stream in listener.incoming() {
        let stream = stream?;
        let store = Arc::clone(&store);

        // Spawn a new OS thread for each client connection.
        thread::spawn(move || {
            if let Err(e) = handle_client(stream, store) {
                eprintln!("client error: {}", e);
            }
        });
    }

    Ok(())
}

/// Handles a single client connection.
///
/// # Parameters
///
/// - `socket`: The TCP stream representing the client connection.
/// - `store`: Shared reference to the in-memory key-value store.
///
/// # Behavior
///
/// - Sends a greeting line to the client: `+TinyKV ready\r\n`.
/// - Reads lines from the client in a loop.
/// - For each non-empty line:
///   - Parses and executes a command via [`handle_command`].
///   - Writes the response back to the client.
///
/// When the client closes the connection (EOF), the function returns.
///
/// # Errors
///
/// Any I/O error that occurs when reading from or writing to the socket
/// is returned as `std::io::Error`.
fn handle_client(socket: TcpStream, store: Store) -> std::io::Result<()> {
    // We need a writer and a reader:
    // - `writer` writes responses to the client.
    // - `reader` reads line-based commands from the same socket.
    let mut writer = socket.try_clone()?;
    let mut reader = BufReader::new(socket);

    // Initial greeting so the client knows the server is ready.
    writer.write_all(b"+TinyKV ready\r\n")?;

    let mut line = String::new();

    loop {
        line.clear();

        // Read a single line (blocking). `read_line` includes the trailing newline.
        let n = reader.read_line(&mut line)?;
        if n == 0 {
            // `n == 0` means EOF: client closed the connection.
            break;
        }

        // Trim whitespace and newlines to get the raw command.
        let response = handle_command(line.trim(), &store);

        // Write the protocol-formatted response back to the client.
        writer.write_all(response.as_bytes())?;
        writer.flush()?;
    }

    Ok(())
}

/// Parses and executes a TinyKV command.
///
/// # Supported commands
///
/// - `SET key value`
///   - Stores `value` under `key`.
///   - Response: `+OK\r\n`
///
/// - `GET key`
///   - Looks up the value for `key`.
///   - If found: `$<len>\r\n<value>\r\n`
///   - If not found: `$-1\r\n`
///
/// - `DEL key`
///   - Deletes the given key from the store.
///   - If a key was deleted: `:1\r\n`
///   - If key did not exist: `:0\r\n`
///
/// Any other command returns:
/// - `-ERR unknown command\r\n`
///
/// # Parameters
///
/// - `cmd`: A single line command string without trailing newlines.
/// - `store`: Shared reference to the key-value store.
///
/// # Returns
///
/// A `String` containing the full protocol response (including `\r\n`).
fn handle_command(cmd: &str, store: &Store) -> String {
    // Split the input into at most 3 parts:
    //   1. command name (e.g., "SET")
    //   2. key
    //   3. value (which may contain spaces)
    let parts: Vec<&str> = cmd.splitn(3, ' ').collect();

    match parts.as_slice() {
        // SET key value
        ["SET", key, value] => {
            // Obtain a write lock because we're modifying the map.
            let mut map = store.write().unwrap();
            map.insert((*key).to_string(), (*value).to_string());
            "+OK\r\n".to_string()
        }

        // GET key
        ["GET", key] => {
            // Read lock: multiple clients can GET concurrently.
            let map = store.read().unwrap();
            match map.get(*key) {
                Some(v) => {
                    // Return length-prefixed bulk string: `$<len>\r\n<value>\r\n`
                    format!("${}\r\n{}\r\n", v.len(), v)
                }
                None => {
                    // `$-1\r\n` indicates a null / missing value.
                    "$-1\r\n".to_string()
                }
            }
        }

        // DEL key
        ["DEL", key] => {
            // Write lock: we might remove an entry.
            let mut map = store.write().unwrap();
            let existed = map.remove(*key).is_some();

            if existed {
                // `:1` means one key was deleted.
                ":1\r\n".to_string()
            } else {
                // `:0` means nothing was deleted.
                ":0\r\n".to_string()
            }
        }

        // Anything else: unknown command.
        _ => "-ERR unknown command\r\n".to_string(),
    }
}
```

I dunno how to raw-dog code in rust. So, we compile it as follow:

```bash
$ rustc tiny_kv.rs
```

and now we start the server:

```bash
$ ./tiny_kv

TinyKV (std) listening on 127.0.0.1:4040
```

in a differen terminal session execute telnet:

```bash
$ telnet 127.0.0.1 4040

Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
+TinyKV ready
SET foo bar
+OK
GET foo
$3
bar
DEL foo
:1
GET foo
$-1

```
