defmodule MDExBlockTags.HTML do
  @moduledoc """
  Serialises a `MDExBlockTags.Marker` into the opening and closing HTML tags
  that wrap a block.

  Attribute values are escaped because they are always author-controlled.
  Attribute names are escaped too, as defence in depth: `MDExBlockTags.Marker`
  already validates them against an allowlist and a character set before they
  reach this module, so for a valid name the escape is a no-op, but a future
  bug in that validation cannot turn into markup injection here.
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
