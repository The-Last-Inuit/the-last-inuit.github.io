defmodule Intervals do
  @moduledoc """
  Merges overlapping (or touching) intervals.

  Intervals are represented as `{start, end}` tuples (typically integers).
  The merge rule used here is:

  * Two intervals overlap/touch if `next_start <= prev_end`.
  * When they do, they merge into `{prev_start, max(prev_end, next_end)}`.

  The result is sorted by start (and end) in ascending order.

  ## Complexity

  * Time: `O(n log n)` due to sorting
  * Space: `O(n)` for the output

  ## Assumptions / input validation

  This module assumes each interval is a 2-tuple and that `start <= end`.
  If you may receive reversed intervals like `{5, 2}`, normalize them before calling `merge/1`.
  """

  @typedoc "An interval represented as `{start, end}`."
  @type interval(t) :: {t, t}
  @type interval :: interval(integer())

  @doc """
  Merges a list of intervals.

  Returns a list of merged intervals, sorted ascending.

  Touching intervals are merged:

      iex> Intervals.merge([{1, 2}, {2, 3}])
      [{1, 3}]

  ## Examples

      iex> Intervals.merge([])
      []

      iex> Intervals.merge([{1, 3}, {2, 6}, {8, 10}, {15, 18}])
      [{1, 6}, {8, 10}, {15, 18}]

      iex> Intervals.merge([{5, 7}, {1, 2}, {3, 4}])
      [{1, 2}, {3, 4}, {5, 7}]
  """
  @spec merge([interval(integer())]) :: [interval(integer())]
  def merge([]), do: []

  def merge(intervals) when is_list(intervals) do
    intervals
    |> Enum.sort_by(fn {s, e} -> {s, e} end)
    |> Enum.reduce([], fn {s, e}, acc ->
      case acc do
        [] ->
          [{s, e}]

        [{ps, pe} | rest] ->
          if s <= pe do
            [{ps, max(pe, e)} | rest]
          else
            [{s, e} | acc]
          end
      end
    end)
    |> Enum.reverse()
  end
end

ExUnit.start()

defmodule IntervalsTest do
  use ExUnit.Case, async: true

  describe "merge/1" do
    test "empty input" do
      assert Intervals.merge([]) == []
    end

    test "single interval" do
      assert Intervals.merge([{1, 2}]) == [{1, 2}]
    end

    test "already sorted, overlapping" do
      assert Intervals.merge([{1, 3}, {2, 6}, {8, 10}, {15, 18}]) ==
               [{1, 6}, {8, 10}, {15, 18}]
    end

    test "unsorted input is handled" do
      assert Intervals.merge([{8, 10}, {1, 3}, {2, 6}]) == [{1, 6}, {8, 10}]
    end

    test "non-overlapping intervals remain separate and sorted" do
      assert Intervals.merge([{5, 7}, {1, 2}, {3, 4}]) == [{1, 2}, {3, 4}, {5, 7}]
    end

    test "touching intervals merge (s <= previous_end)" do
      assert Intervals.merge([{1, 2}, {2, 3}]) == [{1, 3}]
      assert Intervals.merge([{1, 1}, {1, 2}]) == [{1, 2}]
    end

    test "contained intervals collapse into the outer one" do
      assert Intervals.merge([{1, 10}, {2, 3}, {4, 8}]) == [{1, 10}]
    end

    test "duplicates collapse" do
      assert Intervals.merge([{1, 2}, {1, 2}, {1, 2}]) == [{1, 2}]
    end

    test "property check vs brute merge on small cases" do
      cases = [
        [{1, 3}, {4, 6}],
        [{1, 4}, {2, 3}],
        [{5, 6}, {1, 2}, {2, 4}],
        [{1, 2}, {3, 5}, {4, 4}],
        [{0, 0}, {0, 1}, {2, 2}]
      ]

      Enum.each(cases, fn intervals ->
        assert Intervals.merge(intervals) == brute_merge(intervals)
      end)
    end
  end

  defp brute_merge(intervals) do
    intervals
    |> Enum.sort_by(fn {s, e} -> {s, e} end)
    |> Enum.reduce([], fn {s, e}, acc ->
      case acc do
        [] ->
          [{s, e}]

        [{ps, pe} | rest] ->
          if s <= pe do
            [{ps, max(pe, e)} | rest]
          else
            [{s, e} | acc]
          end
      end
    end)
    |> Enum.reverse()
  end
end
