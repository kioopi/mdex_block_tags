defmodule MDExBlockTags.Rewriter do
  @moduledoc """
  Rewrites a flat list of MDEx nodes, wrapping the regions delimited by markers
  in synthetic `MDEx.HtmlBlock` opening and closing tags.

  Blocks are flat in this version: opening a block implicitly closes the
  previous one, and any block still open at the end of the document is closed
  there. The fold is written around a stack whose depth is capped at
  `@max_depth`, so nesting becomes a change to that constant rather than a
  rewrite.

  Both the output list and each block's children accumulate in reverse, and the
  whole result is reversed once at the end.

  A closed block is rendered by `MDExBlockTags.Handlers.render/4`, which
  applies the host's `:block_tags_handlers`. This module only tracks block
  structure — where each block starts and ends, and what belongs to it — and
  hands the closed block off for rendering.
  """

  alias MDExBlockTags.Handlers
  alias MDExBlockTags.Marker

  # Flat blocks. Raise this (or set it to :infinity) to allow nesting.
  @max_depth 1

  @typedoc """
  `Marker.config()` plus the handlers to apply to each closed block.
  """
  @type config :: %{
          required(:allowed_tags) => [String.t()],
          required(:allowed_attributes) => [String.t()],
          optional(:handlers) => [module()]
        }

  @doc """
  Rewrites `nodes`, wrapping marked regions in HTML block tags.

  ## Examples

      iex> config = %{allowed_tags: ["section"], allowed_attributes: []}
      iex> nodes = [%MDEx.HtmlBlock{literal: "<!-- @section intro -->\\n"}]
      iex> [open, close] = MDExBlockTags.Rewriter.run(nodes, config)
      iex> {open.literal, close.literal}
      {~s(<section class="intro">\\n), "</section>\\n"}

  """
  @spec run([MDEx.Document.md_node()], config()) :: [MDEx.Document.md_node()]
  def run(nodes, config) do
    {stack, output} = Enum.reduce(nodes, {[], []}, &step(&1, &2, config))
    {[], output} = close_all(stack, output, config)

    Enum.reverse(output)
  end

  defp step(node, {stack, output}, config) do
    case classify(node, config) do
      {:open, marker} ->
        {stack, output} =
          if length(stack) >= @max_depth do
            close_top(stack, output, config)
          else
            {stack, output}
          end

        {[new_block(marker, node) | stack], output}

      :close ->
        case stack do
          # Orphan @end: leave the comment alone.
          [] -> {stack, [node | output]}
          _ -> close_top(stack, output, config)
        end

      :ordinary ->
        case stack do
          [] -> {stack, [node | output]}
          [block | rest] -> {[%{block | nodes: [node | block.nodes]} | rest], output}
        end
    end
  end

  defp classify(%MDEx.HtmlBlock{literal: literal}, config), do: Marker.parse(literal, config)
  defp classify(_node, _config), do: :ordinary

  defp new_block(marker, node) do
    %{marker: marker, nodes: [], sourcepos: node.sourcepos}
  end

  defp close_all([], output, _config), do: {[], output}

  defp close_all(stack, output, config) do
    {stack, output} = close_top(stack, output, config)
    close_all(stack, output, config)
  end

  defp close_top([block | rest], output, config) do
    # Handlers.render/4 works in document order; the accumulators here are
    # reversed, so the children go in reversed and the result comes out
    # reversed.
    wrapped =
      block.marker
      |> Handlers.render(
        Enum.reverse(block.nodes),
        block.sourcepos,
        Map.get(config, :handlers, [])
      )
      |> Enum.reverse()

    case rest do
      [] -> {rest, wrapped ++ output}
      [parent | tail] -> {[%{parent | nodes: wrapped ++ parent.nodes} | tail], output}
    end
  end
end
