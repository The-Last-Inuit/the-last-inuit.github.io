defmodule BinSearch do
  @moduledoc """
  Binary search utilities over sorted lists and monotone predicates.

  Provided functions:

  * `lower_bound/2`: first index `i` such that `a[i] >= x`
  * `upper_bound/2`: first index `i` such that `a[i] > x`
  * `first_true/3`: first integer `i` in `[lo, hi)` where a monotone predicate becomes `true`
  * `last_true/3`: last integer `i` in `[lo, hi)` where a monotone predicate is `true`

  ## Conventions

  * Indices are 0-based.
  * Ranges are half-open: `[lo, hi)`.
  * For bounds functions, if no element satisfies the condition, the returned index is `length(a)`.

  ## Requirements

  * `lower_bound/2` and `upper_bound/2` require `a` to be sorted ascending according to Erlang/Elixir term order.
  * `first_true/3` and `last_true/3` require `pred` to be **monotone** on `[lo, hi)`:
    there exists some threshold `t` such that `pred(i)` is false for `i < t` and true for `i >= t`.
  """

  @typedoc "0-based index into a list."
  @type index :: non_neg_integer()

  @typedoc "A half-open integer range `[lo, hi)`."
  @type lo :: integer()
  @type hi :: integer()

  @doc """
  Returns the first index `i` in `0..length(a)` where `Enum.at(a, i) >= x`.

  If all elements are `< x`, returns `length(a)`.

  ## Examples

      iex> BinSearch.lower_bound([1, 2, 2, 4], 2)
      1

      iex> BinSearch.lower_bound([1, 2, 2, 4], 3)
      3

      iex> BinSearch.lower_bound([], 10)
      0
  """
  @spec lower_bound([term()], term()) :: index()
  def lower_bound(a, x), do: lb(a, x, 0, length(a))

  @spec lb([term()], term(), index(), index()) :: index()
  defp lb(_a, _x, lo, hi) when lo >= hi, do: lo

  defp lb(a, x, lo, hi) do
    mid = lo + div(hi - lo, 2)
    if Enum.at(a, mid) >= x, do: lb(a, x, lo, mid), else: lb(a, x, mid + 1, hi)
  end

  @doc """
  Returns the first index `i` in `0..length(a)` where `Enum.at(a, i) > x`.

  If all elements are `<= x`, returns `length(a)`.

  ## Examples

      iex> BinSearch.upper_bound([1, 2, 2, 4], 2)
      3

      iex> BinSearch.upper_bound([1, 2, 2, 4], 4)
      4

      iex> BinSearch.upper_bound([], 10)
      0
  """
  @spec upper_bound([term()], term()) :: index()
  def upper_bound(a, x), do: ub(a, x, 0, length(a))

  @spec ub([term()], term(), index(), index()) :: index()
  defp ub(_a, _x, lo, hi) when lo >= hi, do: lo

  defp ub(a, x, lo, hi) do
    mid = lo + div(hi - lo, 2)
    if Enum.at(a, mid) > x, do: ub(a, x, lo, mid), else: ub(a, x, mid + 1, hi)
  end

  @doc """
  Given integers `lo` and `hi`, returns the smallest integer `i` in `[lo, hi)`
  such that `pred.(i)` is `true`.

  If `pred` is `false` for all `i` in `[lo, hi)`, returns `hi`.

  ## Requirements

  `pred` must be monotone on `[lo, hi)` (false...false, then true...true).

  ## Examples

      iex> BinSearch.first_true(0, 10, fn i -> i >= 7 end)
      7

      iex> BinSearch.first_true(0, 5, fn _ -> false end)
      5
  """
  @spec first_true(lo(), hi(), (integer() -> as_boolean(term()))) :: integer()
  def first_true(lo, hi, pred) when is_integer(lo) and is_integer(hi) and is_function(pred, 1) do
    if lo >= hi do
      lo
    else
      mid = lo + div(hi - lo, 2)
      if pred.(mid), do: first_true(lo, mid, pred), else: first_true(mid + 1, hi, pred)
    end
  end

  @doc """
  Returns the greatest integer `i` in `[lo, hi)` such that `pred.(i)` is `true`.

  If `pred` is `false` for all `i` in `[lo, hi)`, returns `lo - 1`.

  This is implemented via `first_true/3` by searching for the first index where `pred` becomes false.

  ## Requirements

  `pred` must be monotone on `[lo, hi)`.

  ## Examples

      iex> BinSearch.last_true(0, 10, fn i -> i < 7 end)
      6

      iex> BinSearch.last_true(0, 10, fn _ -> false end)
      -1
  """
  @spec last_true(lo(), hi(), (integer() -> as_boolean(term()))) :: integer()
  def last_true(lo, hi, pred) when is_integer(lo) and is_integer(hi) and is_function(pred, 1) do
    i = first_true(lo, hi, fn j -> not pred.(j) end)
    i - 1
  end
end

ExUnit.start()

defmodule BinSearchTest do
  use ExUnit.Case, async: true

  describe "lower_bound/2" do
    test "empty list" do
      assert BinSearch.lower_bound([], 10) == 0
    end

    test "basic positions" do
      a = [1, 2, 2, 4]
      assert BinSearch.lower_bound(a, 0) == 0
      assert BinSearch.lower_bound(a, 1) == 0
      assert BinSearch.lower_bound(a, 2) == 1
      assert BinSearch.lower_bound(a, 3) == 3
      assert BinSearch.lower_bound(a, 4) == 3
      assert BinSearch.lower_bound(a, 5) == 4
    end

    test "works with arbitrary terms (term ordering)" do
      a = [:a, :b, :b, :c]
      assert BinSearch.lower_bound(a, :b) == 1
      assert BinSearch.lower_bound(a, :bb) == 3
    end

    test "agrees with brute force" do
      cases = [
        {[], 1},
        {[1], 0},
        {[1], 1},
        {[1], 2},
        {[1, 1, 1], 1},
        {[1, 2, 2, 4], 2},
        {[1, 2, 2, 4], 3}
      ]

      Enum.each(cases, fn {a, x} ->
        assert BinSearch.lower_bound(a, x) == brute_lower_bound(a, x)
      end)
    end
  end

  describe "upper_bound/2" do
    test "empty list" do
      assert BinSearch.upper_bound([], 10) == 0
    end

    test "basic positions" do
      a = [1, 2, 2, 4]
      assert BinSearch.upper_bound(a, 0) == 0
      assert BinSearch.upper_bound(a, 1) == 1
      assert BinSearch.upper_bound(a, 2) == 3
      assert BinSearch.upper_bound(a, 3) == 3
      assert BinSearch.upper_bound(a, 4) == 4
      assert BinSearch.upper_bound(a, 5) == 4
    end

    test "agrees with brute force" do
      cases = [
        {[], 1},
        {[1], 0},
        {[1], 1},
        {[1], 2},
        {[1, 1, 1], 1},
        {[1, 2, 2, 4], 2},
        {[1, 2, 2, 4], 3}
      ]

      Enum.each(cases, fn {a, x} ->
        assert BinSearch.upper_bound(a, x) == brute_upper_bound(a, x)
      end)
    end
  end

  describe "first_true/3" do
    test "returns threshold when predicate flips false->true" do
      assert BinSearch.first_true(0, 10, fn i -> i >= 7 end) == 7
      assert BinSearch.first_true(-5, 6, fn i -> i >= 0 end) == 0
    end

    test "all false returns hi" do
      assert BinSearch.first_true(0, 5, fn _ -> false end) == 5
    end

    test "all true returns lo" do
      assert BinSearch.first_true(0, 5, fn _ -> true end) == 0
    end

    test "lo >= hi returns lo (empty range)" do
      assert BinSearch.first_true(3, 3, fn _ -> true end) == 3
      assert BinSearch.first_true(5, 2, fn _ -> true end) == 5
    end
  end

  describe "last_true/3" do
    test "returns last index satisfying monotone predicate" do
      assert BinSearch.last_true(0, 10, fn i -> i < 7 end) == 6
      assert BinSearch.last_true(0, 10, fn i -> i <= 0 end) == 0
    end

    test "all false returns lo-1" do
      assert BinSearch.last_true(0, 10, fn _ -> false end) == -1
      assert BinSearch.last_true(5, 10, fn _ -> false end) == 4
    end

    test "all true returns hi-1" do
      assert BinSearch.last_true(0, 10, fn _ -> true end) == 9
      assert BinSearch.last_true(-3, 2, fn _ -> true end) == 1
    end
  end

  defp brute_lower_bound(a, x) do
    a
    |> Enum.with_index()
    |> Enum.find_value(length(a), fn {v, i} -> if v >= x, do: i, else: nil end)
  end

  defp brute_upper_bound(a, x) do
    a
    |> Enum.with_index()
    |> Enum.find_value(length(a), fn {v, i} -> if v > x, do: i, else: nil end)
  end
end
