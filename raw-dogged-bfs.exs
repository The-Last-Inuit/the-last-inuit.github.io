defmodule BFSGrid do
  @moduledoc """
  Shortest path on a 2D grid using BFS (4-directional movement).

  The grid is a list of rows, where each cell is:

  * `0` = open
  * `1` = blocked (wall)

  Coordinates are `{row, col}` with zero-based indices.

  Returns the length (number of steps) of the shortest path from `start` to `goal`,
  or `-1` if no path exists or the input is invalid.

  ## Notes / assumptions

  * Requires a rectangular grid (all rows same length).
  * Movement is 4-neighborhood: up, down, left, right (no diagonals).
  * If `start == goal`, returns `0` (as long as the cell is in-bounds and not blocked).

  ## Complexity

  BFS visits each reachable cell at most once.

  * Time: `O(rows * cols)`
  * Space: `O(rows * cols)` for the queue + visited set
  """

  @typedoc "Grid where 0=open and 1=blocked."
  @type grid :: [[0 | 1]]

  @typedoc "Coordinate in `{row, col}` form (0-based)."
  @type coord :: {integer(), integer()}

  @doc """
  Computes the shortest path length from `{sr, sc}` to `{gr, gc}`.

  Returns `-1` when:

  * grid is empty
  * start/goal is out of bounds
  * start/goal is blocked (`1`)
  * no path exists

  ## Examples

      iex> grid = [
      ...>   [0, 0, 0],
      ...>   [1, 1, 0],
      ...>   [0, 0, 0]
      ...> ]
      iex> BFSGrid.shortest_path(grid, {0, 0}, {2, 2})
      4

      iex> BFSGrid.shortest_path([], {0, 0}, {0, 0})
      -1

      iex> BFSGrid.shortest_path([[1]], {0, 0}, {0, 0})
      -1

      iex> BFSGrid.shortest_path([[0]], {0, 0}, {0, 0})
      0
  """
  @spec shortest_path(grid(), coord(), coord()) :: integer()
  def shortest_path(grid, {sr, sc}, {gr, gc})
      when is_list(grid) and is_integer(sr) and is_integer(sc) and is_integer(gr) and
             is_integer(gc) do
    r = length(grid)
    if r == 0, do: -1, else: do_bfs(grid, {sr, sc}, {gr, gc})
  end

  @spec do_bfs(grid(), coord(), coord()) :: integer()
  defp do_bfs(grid, start, goal) do
    rows = length(grid)
    cols = length(hd(grid))

    in_bounds = fn {r, c} -> r >= 0 and r < rows and c >= 0 and c < cols end
    cell = fn {r, c} -> grid |> Enum.at(r) |> Enum.at(c) end

    cond do
      not in_bounds.(start) or not in_bounds.(goal) ->
        -1

      cell.(start) == 1 or cell.(goal) == 1 ->
        -1

      start == goal ->
        0

      true ->
        q = :queue.in({start, 0}, :queue.new())
        vis = MapSet.new([start])
        bfs_loop(q, vis, in_bounds, cell, goal)
    end
  end

  @spec bfs_loop(:queue.queue(), MapSet.t(), (coord() -> boolean()), (coord() -> 0 | 1), coord()) ::
          integer()
  defp bfs_loop(q, vis, in_bounds, cell, goal) do
    case :queue.out(q) do
      {{:value, {{r, c}, d}}, q2} ->
        dirs = [{1, 0}, {-1, 0}, {0, 1}, {0, -1}]

        {q3, vis3, found} =
          Enum.reduce(dirs, {q2, vis, nil}, fn {dr, dc}, {qq, vv, found} ->
            if found do
              {qq, vv, found}
            else
              nxt = {r + dr, c + dc}

              cond do
                not in_bounds.(nxt) -> {qq, vv, nil}
                MapSet.member?(vv, nxt) -> {qq, vv, nil}
                cell.(nxt) == 1 -> {qq, vv, nil}
                nxt == goal -> {qq, vv, d + 1}
                true -> {:queue.in({nxt, d + 1}, qq), MapSet.put(vv, nxt), nil}
              end
            end
          end)

        if found, do: found, else: bfs_loop(q3, vis3, in_bounds, cell, goal)

      {:empty, _} ->
        -1
    end
  end
end

ExUnit.start()

defmodule BFSGridTest do
  use ExUnit.Case, async: true

  describe "shortest_path/3" do
    test "empty grid returns -1" do
      assert BFSGrid.shortest_path([], {0, 0}, {0, 0}) == -1
    end

    test "start == goal returns 0 when in-bounds and open" do
      assert BFSGrid.shortest_path([[0]], {0, 0}, {0, 0}) == 0
    end

    test "start == goal returns -1 when blocked" do
      assert BFSGrid.shortest_path([[1]], {0, 0}, {0, 0}) == -1
    end

    test "out-of-bounds start or goal returns -1" do
      grid = [
        [0, 0],
        [0, 0]
      ]

      assert BFSGrid.shortest_path(grid, {-1, 0}, {1, 1}) == -1
      assert BFSGrid.shortest_path(grid, {0, 0}, {2, 0}) == -1
    end

    test "blocked start or goal returns -1" do
      grid = [
        [1, 0],
        [0, 0]
      ]

      assert BFSGrid.shortest_path(grid, {0, 0}, {1, 1}) == -1

      grid2 = [
        [0, 0],
        [0, 1]
      ]

      assert BFSGrid.shortest_path(grid2, {0, 0}, {1, 1}) == -1
    end

    test "finds a shortest path in a simple open grid (Manhattan distance)" do
      grid = [
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0]
      ]

      assert BFSGrid.shortest_path(grid, {0, 0}, {2, 2}) == 4
      assert BFSGrid.shortest_path(grid, {1, 1}, {2, 0}) == 2
    end

    test "navigates around walls" do
      grid = [
        [0, 0, 0],
        [1, 1, 0],
        [0, 0, 0]
      ]

      assert BFSGrid.shortest_path(grid, {0, 0}, {2, 2}) == 4
    end

    test "returns -1 when no path exists" do
      grid = [
        [0, 1, 0],
        [1, 1, 1],
        [0, 1, 0]
      ]

      assert BFSGrid.shortest_path(grid, {0, 0}, {2, 2}) == -1
    end

    test "handles non-square grids" do
      grid = [
        [0, 0, 1, 0],
        [0, 0, 1, 0]
      ]

      assert BFSGrid.shortest_path(grid, {0, 0}, {1, 3}) == -1
    end

    test "agrees with a brute-force BFS implementation on small cases" do
      cases = [
        {[[0]], {0, 0}, {0, 0}},
        {[[0, 0], [0, 0]], {0, 0}, {1, 1}},
        {[[0, 1], [0, 0]], {0, 0}, {1, 1}},
        {[[0, 1, 0], [0, 1, 0], [0, 0, 0]], {0, 0}, {2, 2}}
      ]

      Enum.each(cases, fn {grid, s, g} ->
        assert BFSGrid.shortest_path(grid, s, g) == brute_bfs(grid, s, g)
      end)
    end
  end

  defp brute_bfs(grid, start, goal) do
    rows = length(grid)
    if rows == 0, do: -1, else: :ok
    cols = length(hd(grid))

    in_bounds? = fn {r, c} -> r in 0..(rows - 1) and c in 0..(cols - 1) end
    cell = fn {r, c} -> grid |> Enum.at(r) |> Enum.at(c) end

    cond do
      rows == 0 ->
        -1

      not in_bounds?.(start) or not in_bounds?.(goal) ->
        -1

      cell.(start) == 1 or cell.(goal) == 1 ->
        -1

      start == goal ->
        0

      true ->
        q = :queue.in({start, 0}, :queue.new())
        vis = MapSet.new([start])
        dirs = [{1, 0}, {-1, 0}, {0, 1}, {0, -1}]
        brute_loop(q, vis, dirs, in_bounds?, cell, goal)
    end
  end

  defp brute_loop(q, vis, dirs, in_bounds?, cell, goal) do
    case :queue.out(q) do
      {{:value, {pos, d}}, q2} ->
        if pos == goal do
          d
        else
          {q3, vis3} =
            Enum.reduce(dirs, {q2, vis}, fn {dr, dc}, {qq, vv} ->
              {r, c} = pos
              nxt = {r + dr, c + dc}

              cond do
                not in_bounds?.(nxt) -> {qq, vv}
                MapSet.member?(vv, nxt) -> {qq, vv}
                cell.(nxt) == 1 -> {qq, vv}
                true -> {:queue.in({nxt, d + 1}, qq), MapSet.put(vv, nxt)}
              end
            end)

          brute_loop(q3, vis3, dirs, in_bounds?, cell, goal)
        end

      {:empty, _} ->
        -1
    end
  end
end
