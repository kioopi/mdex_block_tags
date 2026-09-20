defmodule MDExBlockTags.HTML do
  @moduledoc """
  Serialises a `MDExBlockTags.Marker` into the opening and closing HTML tags
  that wrap a block.

  Attribute *values* are escaped; attribute *names* are not, because they have
  already passed the allowlist in `MDExBlockTags.Marker`.
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

  defp class_attribute(classes) do
    ~s( class="#{escape_attribute(Enum.join(classes, " "))}")
  end

  defp attributes_string(attributes) do
    Enum.map_join(attributes, "", fn {name, value} ->
      ~s( #{name}="#{escape_attribute(value)}")
    end)
  end

  @doc """
  Escapes a value for use inside a double-quoted HTML attribute.

  `&` is replaced first, so the entities introduced by the later replacements
  are not escaped a second time.

  ## Examples

      iex> MDExBlockTags.HTML.escape_attribute(~s(Tom & "Jerry"))
      "Tom &amp; &quot;Jerry&quot;"

  """
  @spec escape_attribute(String.t()) :: String.t()
  def escape_attribute(value) do
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
