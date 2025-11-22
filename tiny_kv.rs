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

// we compile it as follow:

// $ rustc tiny_kv.rs

// and now we start the server:

// $ ./tiny_kv
// TinyKV (std) listening on 127.0.0.1:4040

// in a differen terminal session execute telnet:

// telnet 127.0.0.1 4040
//   Trying 127.0.0.1...
//   Connected to localhost.
//   Escape character is '^]'.
//   +TinyKV ready
//   SET foo bar
//   +OK
//   GET foo
//   $3
//   bar
//   DEL foo
//   :1
//   GET foo
//   $-1
