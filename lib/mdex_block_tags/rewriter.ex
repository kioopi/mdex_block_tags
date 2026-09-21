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
  """

  alias MDExBlockTags.HTML
  alias MDExBlockTags.Marker

  # Flat blocks. Raise this (or set it to :infinity) to allow nesting.
  @max_depth 1

  @doc """
  Rewrites `nodes`, wrapping marked regions in HTML block tags.

  ## Examples

      iex> config = %{allowed_tags: ["section"], allowed_attributes: []}
      iex> nodes = [%MDEx.HtmlBlock{literal: "<!-- @section intro -->\\n"}]
      iex> [open, close] = MDExBlockTags.Rewriter.run(nodes, config)
      iex> {open.literal, close.literal}
      {~s(<section class="intro">\\n), "</section>\\n"}

  """
  @spec run([MDEx.Document.md_node()], Marker.config()) :: [MDEx.Document.md_node()]
  def run(nodes, config) do
    {stack, output} = Enum.reduce(nodes, {[], []}, &step(&1, &2, config))
    {[], output} = close_all(stack, output)

    Enum.reverse(output)
  end

  defp step(node, {stack, output}, config) do
    case classify(node, config) do
      {:open, marker} ->
        {stack, output} =
          if length(stack) >= @max_depth do
            close_top(stack, output)
          else
            {stack, output}
          end

        {[new_block(marker, node) | stack], output}

      :close ->
        case stack do
          # Orphan @end: leave the comment alone.
          [] -> {stack, [node | output]}
          _ -> close_top(stack, output)
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

  defp close_all([], output), do: {[], output}

  defp close_all(stack, output) do
    {stack, output} = close_top(stack, output)
    close_all(stack, output)
  end

  defp close_top([block | rest], output) do
    # Reverse order: </tag>, children…, <tag>
    wrapped = [closing(block) | block.nodes] ++ [opening(block)]

    case rest do
      [] -> {rest, wrapped ++ output}
      [parent | tail] -> {[%{parent | nodes: wrapped ++ parent.nodes} | tail], output}
    end
  end

  defp opening(%{marker: marker, sourcepos: sourcepos}) do
    HTML.open_tag(marker)
    |> html_block(sourcepos)
  end

  defp closing(%{marker: marker}) do
    HTML.close_tag(marker) |> html_block()
  end

  def html_block(tag) do
    %MDEx.HtmlBlock{literal: tag <> "\n"}
  end

  def html_block(tag, sourcepos) do
    %{html_block(tag) | sourcepos: sourcepos}
  end
end
