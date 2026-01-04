defmodule TopK do
  @moduledoc """
  Utilities for selecting the `k` most frequent **distinct** values from a list.

  ## Approach

  * Build a frequency map in `O(n)`.
  * Keep a min-priority set (size ≤ `k`) using `:gb_sets` keyed by `{count, seq, value}`.
    When the set grows beyond `k`, the smallest `{count, seq, value}` is removed.

  ## Notes on ties

  If multiple values share the same frequency, the function still returns a valid top-`k`,
  but the *relative order among tied items is unspecified*.
  """

  @typedoc "A value from the input list."
  @type value :: term()

  @doc """
  Returns up to `k` values that occur most frequently in `nums`.

  The result is ordered from **most frequent to least frequent**.
  Ties have unspecified order.

  ## Examples

      iex> TopK.top_k_frequent([1, 1, 1, 2, 2, 3], 2)
      [1, 2]

      iex> TopK.top_k_frequent([:a, :b, :a], 10) |> Enum.sort()
      [:a, :b]

      iex> TopK.top_k_frequent([], 3)
      []

      iex> TopK.top_k_frequent([1, 2, 3], 0)
      []
  """
  @spec top_k_frequent([value()], integer()) :: [value()]
  def top_k_frequent(_nums, k) when is_integer(k) and k <= 0, do: []

  def top_k_frequent(nums, k) when is_list(nums) and is_integer(k) do
    freq =
      Enum.reduce(nums, %{}, fn x, acc ->
        Map.update(acc, x, 1, &(&1 + 1))
      end)

    {set, _seq} =
      Enum.reduce(freq, {:gb_sets.empty(), 0}, fn {v, c}, {set, seq} ->
        seq = seq + 1
        set = :gb_sets.add({c, seq, v}, set)

        set =
          if :gb_sets.size(set) > k do
            {_smallest, set2} = :gb_sets.take_smallest(set)
            set2
          else
            set
          end

        {set, seq}
      end)

    extract_desc(set, [])
  end

  @spec extract_desc(term(), [value()]) :: [value()]
  defp extract_desc(set, acc) do
    if :gb_sets.is_empty(set) do
      Enum.reverse(acc)
    else
      {{_c, _seq, v}, set2} = :gb_sets.take_largest(set)
      extract_desc(set2, [v | acc])
    end
  end
end

ExUnit.start()

defmodule TopKTest do
  use ExUnit.Case, async: true

  describe "top_k_frequent/2" do
    test "returns [] when k <= 0" do
      assert TopK.top_k_frequent([1, 2, 3], 0) == []
      assert TopK.top_k_frequent([1, 2, 3], -10) == []
    end

    test "returns [] for empty input" do
      assert TopK.top_k_frequent([], 1) == []
      assert TopK.top_k_frequent([], 10) == []
    end

    test "returns the k most frequent values, ordered by frequency desc" do
      nums = [1, 1, 1, 2, 2, 3]
      assert TopK.top_k_frequent(nums, 2) == [1, 2]
    end

    test "when k exceeds number of distinct values, returns all distinct values" do
      nums = [:a, :b, :a]
      res = TopK.top_k_frequent(nums, 10)

      assert length(res) == 2
      assert MapSet.new(res) == MapSet.new([:a, :b])
    end

    test "works with non-numeric terms" do
      nums = ["x", "y", "x", "z", "x", "y"]
      assert TopK.top_k_frequent(nums, 2) == ["x", "y"]
    end

    test "ties: returns any valid top-k (order among ties unspecified)" do
      nums = [1, 1, 2, 2, 3, 3]
      res = TopK.top_k_frequent(nums, 2)

      assert length(res) == 2
      assert Enum.uniq(res) == res
      assert Enum.all?(res, &(&1 in [1, 2, 3]))

      freq = Enum.frequencies(nums)
      kth = freq |> Map.values() |> Enum.sort(:desc) |> Enum.at(1)
      assert Enum.all?(res, fn v -> Map.fetch!(freq, v) >= kth end)
    end
  end
end
