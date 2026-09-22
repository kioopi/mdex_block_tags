defmodule MDExBlockTags.Handlers do
  @moduledoc """
  Renders a closed block into the flat list of nodes that replaces it,
  applying the host's `MDExBlockTags.Handler` modules on the way.

  `render/4` folds the registered handlers over the block in registration
  order. A matching handler can change the marker, rewrite the children, add
  content at four positions, and add wrappers inside or outside the block's
  own tag. Each handler sees the result of the ones before it and wraps
  everything they built as a unit, so a later handler always sits further from
  the children:

      before · <outer> · <tag> · <inner> · start · children · end · </inner> · </tag> · </outer> · after

  Handler return values are validated here. Handler code is trusted, so a
  malformed return raises `ArgumentError` instead of degrading quietly the way
  a malformed marker does.

  Depends on `MDExBlockTags.HTML` to serialise tags, and on MDEx only for the
  node structs it builds.
  """

  alias MDExBlockTags.HTML
  alias MDExBlockTags.Marker

  @add_positions [:before, :start, :end, :after]
  @wrap_positions [:inner, :outer]

  @doc """
  Renders a block opened by `marker` around `children`, applying `handlers`.

  `children` and the result are in document order. The opening tag carries
  `sourcepos`, the position of the marker comment; nodes built from handler
  output have none.

  ## Examples

      iex> marker = %MDExBlockTags.Marker{tag: "section", classes: ["intro"]}
      iex> [open, close] = MDExBlockTags.Handlers.render(marker, [], %MDEx.Sourcepos{}, [])
      iex> {open.literal, close.literal}
      {~s(<section class="intro">\\n), "</section>\\n"}

  """
  @spec render(Marker.t(), [MDEx.Document.md_node()], MDEx.Sourcepos.t(), [module()]) ::
          [MDEx.Document.md_node()]
  def render(marker, children, sourcepos, handlers) do
    initial = %{marker: marker, children: children, prefix: [], suffix: []}
    block = Enum.reduce(handlers, initial, &apply_handler/2)

    block.prefix ++
      [open_node(block.marker, sourcepos) | block.children] ++
      [close_node(block.marker) | block.suffix]
  end

  defp apply_handler(handler, block) do
    if matches?(handler, block.marker), do: transform(handler, block), else: block
  end

  defp matches?(handler, marker) do
    case handler.match(marker) do
      result when is_boolean(result) -> result
      other -> invalid!(handler, "match/1", "a boolean", other)
    end
  end

  defp marker!(handler, marker) do
    case handler.marker(marker) do
      %Marker{} = marker -> marker
      other -> invalid!(handler, "marker/1", "a %MDExBlockTags.Marker{}", other)
    end
  end

  defp content!(handler, marker, children) do
    case handler.content(marker, children) do
      nodes when is_list(nodes) -> nodes
      other -> invalid!(handler, "content/2", "a list of nodes", other)
    end
  end

  @spec invalid!(module(), String.t(), String.t(), term()) :: no_return()
  defp invalid!(handler, callback, expected, value) do
    raise ArgumentError,
          "#{inspect(handler)}.#{callback} must return #{expected}, got: #{inspect(value)}"
  end

  defp transform(handler, block) do
    marker = marker!(handler, block.marker)
    children = content!(handler, marker, block.children)
    additions = marker |> handler.add() |> entries(:start) |> Enum.map(&addition!(handler, &1))
    wrappers = marker |> handler.wrap() |> entries(:outer) |> Enum.map(&wrapper!(handler, &1))

    {opening, closing} =
      Enum.reduce(at(wrappers, :inner), {at(additions, :start), at(additions, :end)}, &enclose/2)

    {prefix, suffix} = Enum.reduce(at(wrappers, :outer), {block.prefix, block.suffix}, &enclose/2)

    %{
      marker: marker,
      children: opening ++ children ++ closing,
      prefix: at(additions, :before) ++ prefix,
      suffix: suffix ++ at(additions, :after)
    }
  end

  # Each wrapper goes around everything enclosed so far, so the first one
  # ends up closest to the children.
  defp enclose(wrapper, {opening, closing}) do
    {[open_node(wrapper) | opening], closing ++ [close_node(wrapper)]}
  end

  defp addition!(_handler, {position, literal})
       when position in @add_positions and is_binary(literal),
       do: {position, html_block(literal)}

  defp addition!(_handler, {position, %_{} = node}) when position in @add_positions,
    do: {position, node}

  defp addition!(handler, other) do
    invalid!(handler, "add/1", "content keyed by one of #{inspect(@add_positions)}", other)
  end

  defp wrapper!(_handler, {position, %Marker{}} = entry) when position in @wrap_positions,
    do: entry

  defp wrapper!(handler, other) do
    invalid!(handler, "wrap/1", "a %MDExBlockTags.Marker{} keyed by :inner or :outer", other)
  end

  # A bare value is shorthand for a one-entry list at the default position.
  defp entries(value, _default) when is_list(value), do: value
  defp entries(value, default), do: [{default, value}]

  defp at(entries, position), do: for({^position, value} <- entries, do: value)

  defp open_node(marker, sourcepos \\ %MDEx.Sourcepos{}) do
    %{html_block(HTML.open_tag(marker)) | sourcepos: sourcepos}
  end

  defp close_node(marker), do: marker |> HTML.close_tag() |> html_block()

  defp html_block(literal), do: %MDEx.HtmlBlock{literal: literal <> "\n"}
end
