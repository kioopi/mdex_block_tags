defmodule MDExBlockTags.HTML do
  @moduledoc """
  Serialises a `MDExBlockTags.Marker` into the opening and closing HTML tags
  that wrap a block.

  This module renders markers from two sources: markers parsed from Markdown
  by `MDExBlockTags.Marker`, and markers built by handlers via `c:MDExBlockTags.Handler.marker/1`
  and `c:MDExBlockTags.Handler.wrap/1` (see `MDExBlockTags.Handlers`). The two
  are not equally trusted.

  For a marker parsed from Markdown, attribute values are escaped because they
  are always author-controlled. Attribute names are escaped too, as defence in
  depth: `MDExBlockTags.Marker` already validates them against an allowlist
  and a character set before they reach this module, so for a valid name the
  escape is a no-op, but a future bug in that validation cannot turn into
  markup injection here.

  For a marker built by a handler, no such allowlist or character-set check
  has run — handlers are trusted code, not Markdown. `open_tag/1` still
  escapes every attribute name and value, so that escaping is the only guard
  against a handler-built attribute breaking out of its quotes. The tag name
  itself is never escaped, by either source: for a parsed marker that is safe
  because `MDExBlockTags.Marker` only ever produces a `tag` from
  `:block_tags_allowed_tags`, but for a handler-built marker there is no such
  restriction, so a handler is responsible for only ever building a `tag` that
  is valid HTML. `escape/1` is also what handlers use to escape values in the
  raw HTML strings they insert via `c:MDExBlockTags.Handler.add/1`.
  """

  alias MDExBlockTags.Marker

  @doc """
  Renders the opening tag for a marker.

  ## Examples

      iex> marker = %MDExBlockTags.Marker{tag: "section", classes: [], attributes: []}
      iex> MDExBlockTags.HTML.open_tag(marker)
      "<section>"

  """
  @spec open_tag(Marker.t()) :: String.t()
  def open_tag(%Marker{tag: tag, classes: classes, attributes: attributes}) do
    "<" <> tag <> class_attribute(classes) <> attributes_string(attributes) <> ">"
  end

  defp class_attribute([]), do: ""
  defp class_attribute(classes), do: attribute("class", Enum.join(classes, " "))

  defp attributes_string(attributes) do
    Enum.map_join(attributes, "", fn {name, value} -> attribute(name, value) end)
  end

  # The one place a name="value" pair is assembled, so the escaping decision
  # for both name and value exists exactly once.
  defp attribute(name, value) do
    ~s( #{escape(name)}="#{escape(value)}")
  end

  @doc """
  Escapes a string for use inside a double-quoted HTML attribute or as text
  content.

  `&` is replaced first, so the entities introduced by the later replacements
  are not escaped a second time.

  Handlers get this function imported by `use MDExBlockTags.Handler`, for
  building HTML strings from marker values.

  ## Examples

      iex> MDExBlockTags.HTML.escape(~s(Tom & "Jerry"))
      "Tom &amp; &quot;Jerry&quot;"

  """
  @spec escape(String.t()) :: String.t()
  def escape(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  @doc """
  Renders the closing tag for a marker.

  ## Examples

      iex> marker = %MDExBlockTags.Marker{tag: "section", classes: [], attributes: []}
      iex> MDExBlockTags.HTML.close_tag(marker)
      "</section>"

  """
  @spec close_tag(Marker.t()) :: String.t()
  def close_tag(%Marker{tag: tag}), do: "</" <> tag <> ">"
end
