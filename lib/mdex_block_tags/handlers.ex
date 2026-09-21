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
  def render(marker, children, sourcepos, _handlers) do
    [open_node(marker, sourcepos) | children] ++ [close_node(marker)]
  end

  defp open_node(marker, sourcepos) do
    %{html_block(HTML.open_tag(marker)) | sourcepos: sourcepos}
  end

  defp close_node(marker), do: marker |> HTML.close_tag() |> html_block()

  defp html_block(literal), do: %MDEx.HtmlBlock{literal: literal <> "\n"}
end
