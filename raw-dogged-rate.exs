defmodule TokenBucket do
  @moduledoc """
  In-memory token bucket rate limiter.

  The bucket holds up to `cap` tokens. Each `allow/1` attempt:

  * refills tokens based on elapsed time since `last_ms` using `refill_per_sec`
  * caps tokens at `cap`
  * consumes **1.0** token if available and returns `{true, updated_bucket}`
  * otherwise returns `{false, updated_bucket}` (with refilled/capped tokens)

  Uses `System.monotonic_time(:millisecond)` to avoid issues with wall-clock jumps.

  ## Notes

  * Tokens are stored as floats (`0.0`, `1.0`, etc.). This allows fractional refill.
  * Initial tokens are full: `tokens == cap`.
  """

  alias __MODULE__, as: TokenBucket

  @typedoc "Token bucket state."
  @type t :: %TokenBucket{
          cap: float(),
          tokens: float(),
          refill_per_sec: float(),
          last_ms: integer()
        }

  @typedoc "Capacity (tokens) or refill rate (tokens/sec)."
  @type rate :: number()

  defstruct cap: 0.0,
            tokens: 0.0,
            refill_per_sec: 0.0,
            last_ms: nil

  @doc """
  Creates a new bucket with a maximum capacity and refill rate (tokens per second).

  The bucket starts full.

  ## Examples

      iex> b = TokenBucket.new(2, 0)
      iex> {a1, b} = TokenBucket.allow(b)
      iex> {a2, b} = TokenBucket.allow(b)
      iex> {a3, _b} = TokenBucket.allow(b)
      iex> {a1, a2, a3}
      {true, true, false}
  """
  @spec new(rate(), rate()) :: t()
  def new(capacity, refill_per_sec) do
    now = now_ms()

    %TokenBucket{
      cap: capacity * 1.0,
      tokens: capacity * 1.0,
      refill_per_sec: refill_per_sec * 1.0,
      last_ms: now
    }
  end

  @doc """
  Attempts to consume one token.

  Returns `{allowed?, updated_bucket}`.

  * If there is at least 1 token after refilling, it consumes 1 token and returns `true`.
  * Otherwise returns `false` without consuming a token.

  This function always updates `last_ms` to the current monotonic time.
  """
  @spec allow(t()) :: {boolean(), t()}
  def allow(bucket) do
    now = now_ms()
    elapsed = max(now - bucket.last_ms, 0) / 1000.0

    tokens =
      (bucket.tokens + elapsed * bucket.refill_per_sec)
      |> min(bucket.cap)

    if tokens >= 1.0 do
      {true, %{bucket | tokens: tokens - 1.0, last_ms: now}}
    else
      {false, %{bucket | tokens: tokens, last_ms: now}}
    end
  end

  @spec now_ms() :: integer()
  defp now_ms, do: System.monotonic_time(:millisecond)
end

ExUnit.start()

defmodule TokenBucketTest do
  use ExUnit.Case, async: true

  describe "new/2" do
    test "starts full and stores rates as floats" do
      b = TokenBucket.new(5, 2)

      assert b.cap == 5.0
      assert b.tokens == 5.0
      assert b.refill_per_sec == 2.0
      assert is_integer(b.last_ms)
    end
  end

  describe "allow/1" do
    test "consumes one token when available (no refill)" do
      b0 = TokenBucket.new(3, 0)

      {ok, b1} = TokenBucket.allow(b0)
      assert ok == true
      assert b1.tokens == 2.0

      {ok, b2} = TokenBucket.allow(b1)
      assert ok == true
      assert b2.tokens == 1.0

      {ok, b3} = TokenBucket.allow(b2)
      assert ok == true
      assert b3.tokens == 0.0

      {ok, b4} = TokenBucket.allow(b3)
      assert ok == false
      assert b4.tokens == 0.0
    end

    test "denies when < 1 token (no refill)" do
      now = System.monotonic_time(:millisecond)

      b =
        %TokenBucket{
          cap: 10.0,
          tokens: 0.5,
          refill_per_sec: 0.0,
          last_ms: now
        }

      {ok, b2} = TokenBucket.allow(b)
      assert ok == false
      assert b2.tokens == 0.5
    end

    test "refills based on elapsed time and then consumes" do
      now = System.monotonic_time(:millisecond)

      b =
        %TokenBucket{
          cap: 5.0,
          tokens: 0.0,
          refill_per_sec: 2.0,
          last_ms: now - 1_500
        }

      {ok, b2} = TokenBucket.allow(b)
      assert ok == true

      assert_in_delta b2.tokens, 2.0, 0.05
      assert b2.last_ms >= b.last_ms
    end

    test "caps tokens at capacity before consuming" do
      now = System.monotonic_time(:millisecond)

      b =
        %TokenBucket{
          cap: 5.0,
          tokens: 4.9,
          refill_per_sec: 10.0,
          last_ms: now - 1_000
        }

      {ok, b2} = TokenBucket.allow(b)
      assert ok == true

      assert_in_delta b2.tokens, 4.0, 0.05
    end

    test "handles time going backwards by treating elapsed as 0" do
      now = System.monotonic_time(:millisecond)

      b =
        %TokenBucket{
          cap: 2.0,
          tokens: 1.0,
          refill_per_sec: 100.0,
          last_ms: now + 10_000
        }

      {ok, b2} = TokenBucket.allow(b)
      assert ok == true
      assert_in_delta b2.tokens, 0.0, 0.001
    end
  end
end
