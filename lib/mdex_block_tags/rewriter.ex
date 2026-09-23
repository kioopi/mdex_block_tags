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

  A closed block is rendered by default by  `MDExBlockTags.Handlers.render/4`,
  which applies `:block_tags_handlers`. This module only tracks block
  structure — where each block starts and ends, and what belongs to it — and
  hands the closed block off for rendering.
  """

  alias MDExBlockTags.Handlers
  alias MDExBlockTags.Marker
  import Keyword, only: [get: 3, take: 2]

  # Flat blocks. Raise this (or set it to :infinity) to allow nesting.
  @max_depth 1

  @type nodelist :: [MDEx.Document.md_node()]

  @typedoc "Function that transforms an MDEx node."
  @type renderer ::
          (Marker.t(), nodelist(), MDEx.Sourcepos.t() ->
             nodelist())

  @typedoc "Function to classify an MDEx node."
  @type classifier ::
          (MDEx.Document.md_node() -> Marker.classification())

  @type classifier_option ::
          {:classifier, classifier()} | Marker.classify_option()

  @type renderer_option :: {:renderer, renderer()} | Handlers.render_option()

  @typedoc "Options for run/2"
  @type options :: [classifier_option() | renderer_option()]

  @type block :: %{marker: Marker.t(), nodes: nodelist(), sourcepos: MDEx.Sourcepos.t()}
  @type stack :: [block()]

  @doc """
  Rewrites `nodes`, wrapping marked regions in HTML block tags.

  ## Examples

      iex> nodes = [%MDEx.HtmlBlock{literal: "<!-- @section intro -->\\n"}]
      iex> [open, close] = MDExBlockTags.Rewriter.run(nodes)
      iex> {open.literal, close.literal}
      {~s(<section class="intro">\\n), "</section>\\n"}

  """
  @spec run(nodelist()) :: nodelist()
  def run(nodes) do
    run(nodes, [])
  end

  @spec run(nodelist(), options()) :: nodelist()
  def run(nodes, opts) do
    {classifier, renderer} = callbacks(opts)

    {stack, output} =
      Enum.reduce(nodes, {[], []}, fn node, acc ->
        handle_step(classifier.(node), node, acc, renderer)
      end)

    {[], output} = close_all(stack, output, renderer)

    Enum.reverse(output)
  end

  defp callbacks(opts) do
    cb =
      opts
      |> Keyword.validate!(
        [:classifier, :renderer] ++ Marker.options(:keys) ++ Handlers.options(:keys)
      )
      |> defaults()

    {cb[:classifier], cb[:renderer]}
  end

  defp defaults(opts) do
    [
      classifier: get(opts, :classifier, &Marker.classify(&1, take(opts, Marker.options(:keys)))),
      renderer:
        get(opts, :renderer, &Handlers.render(&1, &2, &3, take(opts, Handlers.options(:keys))))
    ]
  end

  @spec handle_step(
          Marker.classification(),
          MDEx.Document.md_node(),
          {stack(), nodelist()},
          renderer()
        ) :: {stack(), nodelist()}
  # Open new block but maximum nesting is reached - close prevous before opening.
  defp handle_step({:open, marker}, node, {stack, output}, renderer)
       when length(stack) >= @max_depth do
    handle_step({:open, marker}, node, close_top(stack, output, renderer), renderer)
  end

  # Open new block
  defp handle_step({:open, marker}, node, {stack, output}, _renderer) do
    {[new_block(marker, node) | stack], output}
  end

  # Orphan @end: leave the comment alone.
  defp handle_step(:close, node, {[], output}, _renderer) do
    {[], [node | output]}
  end

  # Close block
  defp handle_step(:close, _node, {stack, output}, renderer) do
    close_top(stack, output, renderer)
  end

  # Regular node with no block open - just prepend to output
  defp handle_step(:ordinary, node, {[], output}, _renderer) do
    {[], [node | output]}
  end

  # Regular node - add to open block
  defp handle_step(:ordinary, node, {stack, output}, _renderer) do
    [block | rest] = stack
    {[%{block | nodes: [node | block.nodes]} | rest], output}
  end

  @spec new_block(Marker.t(), MDEx.Document.md_node()) :: block()
  defp new_block(marker, node) do
    %{marker: marker, nodes: [], sourcepos: node.sourcepos}
  end

  defp close_all([], output, _renderer), do: {[], output}

  defp close_all(stack, output, renderer) do
    {stack, output} = close_top(stack, output, renderer)
    close_all(stack, output, renderer)
  end

  defp close_top([top | rest], output, renderer) do
    nodes = render(top, renderer)

    case rest do
      [] -> {rest, nodes ++ output}
      [parent | tail] -> {[%{parent | nodes: nodes ++ parent.nodes} | tail], output}
    end
  end

  @spec render(block(), renderer()) :: nodelist()
  defp render(block, renderer) do
    # renderers work in document order but the accumulators here are
    # reversed, so the children go in reversed and the result comes out
    # reversed.
    renderer.(
      block.marker,
      Enum.reverse(block.nodes),
      block.sourcepos
    )
    |> Enum.reverse()
  end
end
