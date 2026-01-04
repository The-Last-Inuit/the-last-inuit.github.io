defmodule SubarraySum do
  @moduledoc """
  Counts how many contiguous subarrays sum to a target `k`.

  ## Idea

  Use prefix sums and a frequency map:

  * Let `prefix[i] = nums[0] + ... + nums[i]`.
  * A subarray `(j+1..i)` sums to `k` iff `prefix[i] - prefix[j] = k`,
    i.e. `prefix[j] = prefix[i] - k`.
  * Keep a map `seen` from prefix sum to how many times we've seen it so far.

  Time: `O(n)`
  Space: `O(n)` (in the worst case, all prefix sums are distinct)

  Works with negative numbers and zeros.
  """

  @typedoc "An integer input list element."
  @type num :: integer()

  @doc """
  Returns the number of contiguous subarrays of `nums` whose sum equals `k`.

  ## Examples

      iex> SubarraySum.count([1, 1, 1], 2)
      2

      iex> SubarraySum.count([1, 2, 3], 3)
      2

      iex> SubarraySum.count([1, -1, 0], 0)
      3

      iex> SubarraySum.count([], 0)
      0
  """
  @spec count([num()], integer()) :: non_neg_integer()
  def count(nums, k) when is_list(nums) and is_integer(k) do
    {ans, _prefix, _seen} =
      Enum.reduce(nums, {0, 0, %{0 => 1}}, fn x, {ans, prefix, seen} ->
        prefix = prefix + x
        ans = ans + Map.get(seen, prefix - k, 0)
        seen = Map.update(seen, prefix, 1, &(&1 + 1))
        {ans, prefix, seen}
      end)

    ans
  end
end

ExUnit.start()

defmodule SubarraySumTest do
  use ExUnit.Case, async: true

  describe "count/2" do
    test "classic example" do
      assert SubarraySum.count([1, 1, 1], 2) == 2
    end

    test "multiple matches across different lengths" do
      assert SubarraySum.count([1, 2, 3], 3) == 2
    end

    test "handles negative numbers" do
      assert SubarraySum.count([1, -1, 0], 0) == 3
    end

    test "all zeros: many subarrays match" do
      assert SubarraySum.count([0, 0, 0, 0], 0) == 10
    end

    test "single element cases" do
      assert SubarraySum.count([5], 5) == 1
      assert SubarraySum.count([5], 0) == 0
    end

    test "empty list" do
      assert SubarraySum.count([], 7) == 0
      assert SubarraySum.count([], 0) == 0
    end

    test "property check vs brute force on small random-ish inputs" do
      cases = [
        {[2, -2, 2, -2], 0},
        {[-1, -1, 1], -1},
        {[3, 4, -7, 1, 3, 3, 1, -4], 7},
        {[1, 2, 1, 2, 1], 3},
        {[10, -10, 10], 10}
      ]

      Enum.each(cases, fn {nums, k} ->
        assert SubarraySum.count(nums, k) == brute_count(nums, k)
      end)
    end
  end

  defp brute_count(nums, k) do
    n = length(nums)

    for i <- 0..(n - 1),
        j <- i..(n - 1),
        reduce: 0 do
      acc ->
        sum =
          nums
          |> Enum.slice(i..j)
          |> Enum.sum()

        if sum == k, do: acc + 1, else: acc
    end
  end
end
