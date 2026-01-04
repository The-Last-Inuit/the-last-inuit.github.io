defmodule LRU do
  @moduledoc """
  Immutable (pure) LRU cache.

  This cache is **persistent/immutable**: every `get/2` returns `{value, new_lru}` and every
  `put/3` returns a **new** `LRU.t()`.

  Internally it maintains:
  - `k2id`: key -> node id
  - `nodes`: node id -> node data (`%{k, v, prev, next}`)
  - `head`/`tail`: ids of a doubly-linked list in **MRU -> LRU** order

  Average complexity:
  - `get/2`: O(1)
  - `put/3`: O(1)

  ## Examples

      iex> lru = LRU.new(2) |> LRU.put(:a, 1) |> LRU.put(:b, 2)
      iex> {1, lru} = LRU.get(lru, :a)     # :a becomes MRU
      iex> lru = LRU.put(lru, :c, 3)       # evicts LRU (:b)
      iex> {nil, _} = LRU.get(lru, :b)
      iex> {1, _} = LRU.get(lru, :a)
  """

  alias __MODULE__, as: LRU

  @typedoc "Cache key."
  @type key :: term()

  @typedoc "Cache value."
  @type value :: term()

  @typedoc "Internal node id."
  @type id :: pos_integer()

  @typedoc "Internal doubly-linked-list node."
  @type n :: %{
          k: key(),
          v: value(),
          prev: id() | nil,
          next: id() | nil
        }

  @typedoc """
  LRU cache struct.

  Invariants (expected to hold after any public operation):
  - `map_size(k2id) == map_size(nodes)`
  - If size == 0: `head == nil` and `tail == nil`
  - If size > 0: `head` and `tail` are valid node ids, and list pointers are consistent
  """
  @type t :: %LRU{
          cap: non_neg_integer(),
          k2id: %{optional(key()) => id()},
          nodes: %{optional(id()) => n()},
          head: id() | nil,
          tail: id() | nil,
          next_id: id()
        }

  defstruct cap: 0,
            k2id: %{},
            nodes: %{},
            head: nil,
            tail: nil,
            next_id: 1

  @doc """
  Creates a new cache with the given `capacity`.

  Capacity may be `0` (a cache that never stores anything).

  ## Examples

      iex> lru = LRU.new(0)
      iex> lru.cap
      0

      iex> lru = LRU.new(2) |> LRU.put(:a, 1)
      iex> {1, _} = LRU.get(lru, :a)
  """
  @spec new(non_neg_integer()) :: t()
  def new(capacity) when is_integer(capacity) and capacity >= 0, do: %LRU{cap: capacity}

  @doc """
  Reads `key` from the cache.

  Returns `{value_or_nil, new_lru}`.
  If the key exists, it is promoted to **most recently used**.

  ## Examples

      iex> lru = LRU.new(2) |> LRU.put(:a, 1) |> LRU.put(:b, 2)
      iex> {1, lru} = LRU.get(lru, :a)  # :a becomes MRU
      iex> lru = LRU.put(lru, :c, 3)    # evicts :b (LRU)
      iex> {nil, _} = LRU.get(lru, :b)
  """
  @spec get(t(), key()) :: {value() | nil, t()}
  def get(lru, key) do
    case Map.get(lru.k2id, key) do
      nil ->
        {nil, lru}

      id ->
        v = lru.nodes[id].v
        lru2 = lru |> detach(id) |> attach_head(id)
        {v, lru2}
    end
  end

  @doc """
  Inserts or updates `key` with `val`.

  - New keys are inserted as **MRU**.
  - Existing keys are updated and promoted to **MRU**.
  - If inserting exceeds capacity, the **LRU** entry is evicted.

  If `cap == 0`, this is a no-op.

  ## Examples

      iex> lru = LRU.new(1) |> LRU.put(:a, 1) |> LRU.put(:b, 2)
      iex> {nil, _} = LRU.get(lru, :a)
      iex> {2, _} = LRU.get(lru, :b)

      iex> lru = LRU.new(2) |> LRU.put(:a, 1) |> LRU.put(:a, 99)
      iex> {99, _} = LRU.get(lru, :a)
  """
  @spec put(t(), key(), value()) :: t()
  def put(%{cap: 0} = lru, _k, _v), do: lru

  def put(lru, key, val) do
    case Map.get(lru.k2id, key) do
      nil ->
        {id, lru1} = alloc_node(lru, key, val)
        lru1 |> attach_head(id) |> evict_if_needed()

      id ->
        lru
        |> put_in([Access.key!(:nodes), id, :v], val)
        |> detach(id)
        |> attach_head(id)
    end
  end

  @spec alloc_node(t(), key(), value()) :: {id(), t()}
  defp alloc_node(lru, key, val) do
    id = lru.next_id
    node = %{k: key, v: val, prev: nil, next: nil}

    lru2 =
      lru
      |> Map.update!(:k2id, &Map.put(&1, key, id))
      |> Map.update!(:nodes, &Map.put(&1, id, node))
      |> Map.put(:next_id, id + 1)

    {id, lru2}
  end

  @spec detach(t(), id()) :: t()
  defp detach(lru, id) do
    node = lru.nodes[id]
    prev = node.prev
    nxt = node.next

    lru =
      lru
      |> put_in([Access.key!(:nodes), id, :prev], nil)
      |> put_in([Access.key!(:nodes), id, :next], nil)

    lru =
      if prev do
        put_in(lru, [Access.key!(:nodes), prev, :next], nxt)
      else
        lru
      end

    lru =
      if nxt do
        put_in(lru, [Access.key!(:nodes), nxt, :prev], prev)
      else
        lru
      end

    lru = if lru.head == id, do: %{lru | head: nxt}, else: lru
    lru = if lru.tail == id, do: %{lru | tail: prev}, else: lru
    lru
  end

  @spec attach_head(t(), id()) :: t()
  defp attach_head(%{head: nil} = lru, id) do
    lru
    |> put_in([Access.key!(:nodes), id, :prev], nil)
    |> put_in([Access.key!(:nodes), id, :next], nil)
    |> Map.put(:head, id)
    |> Map.put(:tail, id)
  end

  defp attach_head(lru, id) do
    old = lru.head

    lru
    |> put_in([Access.key!(:nodes), id, :prev], nil)
    |> put_in([Access.key!(:nodes), id, :next], old)
    |> put_in([Access.key!(:nodes), old, :prev], id)
    |> Map.put(:head, id)
  end

  @spec evict_if_needed(t()) :: t()
  defp evict_if_needed(lru) do
    if map_size(lru.k2id) <= lru.cap do
      lru
    else
      tid = lru.tail
      key = lru.nodes[tid].k

      lru
      |> detach(tid)
      |> Map.update!(:k2id, &Map.delete(&1, key))
      |> Map.update!(:nodes, &Map.delete(&1, tid))
    end
  end
end

ExUnit.start()

defmodule LRUTest do
  use ExUnit.Case, async: true

  defp keys(lru), do: lru.k2id |> Map.keys() |> Enum.sort()

  defp assert_integrity(lru) do
    size = map_size(lru.k2id)

    assert map_size(lru.nodes) == size

    Enum.each(lru.k2id, fn {k, id} ->
      node = Map.fetch!(lru.nodes, id)
      assert node.k == k
    end)

    cond do
      size == 0 ->
        assert lru.head == nil
        assert lru.tail == nil

      true ->
        assert is_integer(lru.head)
        assert is_integer(lru.tail)
        assert Map.has_key?(lru.nodes, lru.head)
        assert Map.has_key?(lru.nodes, lru.tail)

        head_node = Map.fetch!(lru.nodes, lru.head)
        tail_node = Map.fetch!(lru.nodes, lru.tail)

        assert head_node.prev == nil
        assert tail_node.next == nil

        {ids, last} =
          Stream.unfold({lru.head, nil}, fn
            {nil, _prev} ->
              nil

            {id, prev} ->
              node = Map.fetch!(lru.nodes, id)
              assert node.prev == prev
              {{id, node}, {node.next, id}}
          end)
          |> Enum.reduce({[], nil}, fn {id, _node}, {acc, _} -> {[id | acc], id} end)

        ids = Enum.reverse(ids)

        assert Enum.uniq(ids) == ids

        assert length(ids) == size

        assert last == lru.tail
    end

    lru
  end

  test "new/1 sets capacity and empty state" do
    lru = LRU.new(3)
    assert lru.cap == 3
    assert_integrity(lru)
  end

  test "cap=0: put is no-op and get always misses" do
    lru = LRU.new(0)
    lru2 = LRU.put(lru, :a, 1)
    assert lru2 == lru

    assert {nil, ^lru} = LRU.get(lru, :a)
    assert_integrity(lru)
  end

  test "get miss returns {nil, same_lru}" do
    lru = LRU.new(2) |> LRU.put(:a, 1)
    assert {nil, ^lru} = LRU.get(lru, :missing)
    assert_integrity(lru)
  end

  test "put inserts and get hits; get promotes to MRU" do
    lru =
      LRU.new(2)
      |> LRU.put(:a, 1)
      |> LRU.put(:b, 2)

    assert_integrity(lru)

    assert {1, lru2} = LRU.get(lru, :a)
    assert_integrity(lru2)

    lru3 = LRU.put(lru2, :c, 3)
    assert_integrity(lru3)

    assert {nil, _} = LRU.get(lru3, :b)
    assert {1, _} = LRU.get(lru3, :a)
    assert {3, _} = LRU.get(lru3, :c)
  end

  test "put updates existing key value and promotes to MRU without changing size" do
    lru =
      LRU.new(2)
      |> LRU.put(:a, 1)
      |> LRU.put(:b, 2)

    assert keys(lru) == [:a, :b]
    assert_integrity(lru)

    lru2 = LRU.put(lru, :a, 99)
    assert keys(lru2) == [:a, :b]
    assert_integrity(lru2)

    assert {99, _} = LRU.get(lru2, :a)
  end

  test "capacity=1 evicts on second distinct insert" do
    lru =
      LRU.new(1)
      |> LRU.put(:a, 1)
      |> LRU.put(:b, 2)

    assert_integrity(lru)

    assert {nil, _} = LRU.get(lru, :a)
    assert {2, _} = LRU.get(lru, :b)
  end

  test "longer sequence maintains invariants and never exceeds capacity" do
    lru0 = LRU.new(3)

    lru =
      Enum.reduce(1..50, lru0, fn i, lru ->
        lru =
          lru
          |> LRU.put(rem(i, 5), i)
          |> (fn lru ->
                {_v, lru} = LRU.get(lru, rem(i + 2, 5))
                lru
              end).()

        assert_integrity(lru)
        assert map_size(lru.k2id) <= lru.cap
        lru
      end)

    assert_integrity(lru)
  end
end
