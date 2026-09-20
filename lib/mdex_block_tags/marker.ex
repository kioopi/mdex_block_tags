defmodule MDExBlockTags.Marker do
  @moduledoc """
  Recognises the HTML comments that open and close a block.

  A marker is a *complete, standalone* HTML comment whose first content is an
  `@` followed by a command:

      <!-- @section introduction -->
      <!-- @nav main blue id=12 data-open=false -->
      <!-- @end -->

  Anything else — an ordinary comment, a comment with text around it, an
  unknown command — is left alone.

  This module knows nothing about MDEx. It takes the comment text as a binary
  and returns a classification.
  """

  @enforce_keys [:tag]
  defstruct tag: nil, classes: [], attributes: []

  @typedoc "A parsed opening marker."
  @type t :: %__MODULE__{
          tag: String.t(),
          classes: [String.t()],
          attributes: [{String.t(), String.t()}]
        }

  @typedoc """
  What the caller permits.

  `:allowed_tags` are the commands that may open a block; `:allowed_attributes`
  are the attribute names permitted in addition to anything prefixed `data-` or
  `aria-`.
  """
  @type config :: %{
          allowed_tags: [String.t()],
          allowed_attributes: [String.t()]
        }

  @type result :: {:open, t()} | :close | :ordinary

  # Only a complete standalone comment counts.
  #
  #   i — <!-- @SECTION --> matches; the command is downcased.
  #   s — the comment may span several lines.
  #
  @comment ~r/\A\s*<!--\s*@([a-z][a-z0-9-]*)(.*?)-->\s*\z/is

  @doc """
  Classifies a comment literal.

  ## Examples

      iex> config = %{allowed_tags: ["section"], allowed_attributes: ["id"]}
      iex> MDExBlockTags.Marker.parse("<!-- @section -->", config)
      {:open, %MDExBlockTags.Marker{tag: "section", classes: [], attributes: []}}

      iex> config = %{allowed_tags: ["nav"], allowed_attributes: ["id"]}
      iex> MDExBlockTags.Marker.parse(~s(<!-- @nav main blue id=12 -->), config)
      {:open,
       %MDExBlockTags.Marker{
         tag: "nav",
         classes: ["main", "blue"],
         attributes: [{"id", "12"}]
       }}

      iex> config = %{allowed_tags: ["nav"], allowed_attributes: ["id"]}
      iex> MDExBlockTags.Marker.parse("<!-- @end -->", config)
      :close

      iex> config = %{allowed_tags: ["nav"], allowed_attributes: ["id"]}
      iex> MDExBlockTags.Marker.parse("<!-- TODO: rewrite this -->", config)
      :ordinary

  """
  @spec parse(String.t(), config()) :: result()
  def parse(literal, config) when is_binary(literal) do
    case Regex.run(@comment, literal) do
      [_, command, rest] -> classify(String.downcase(command), tokenize(rest), config)
      nil -> :ordinary
    end
  end

  defp classify("end", [], _config), do: :close
  defp classify("end", _tokens, _config), do: :ordinary

  defp classify(tag, tokens, config) do
    if tag in config.allowed_tags do
      case parse_tokens(tokens, config) do
        {:ok, classes, attributes} ->
          {:open, %__MODULE__{tag: tag, classes: classes, attributes: attributes}}

        :error ->
          :ordinary
      end
    else
      :ordinary
    end
  end

  # Bare tokens are CSS classes; key=value tokens are HTML attributes.
  #
  #   @nav main blue id=12 data-open=false
  #
  # becomes classes ["main", "blue"] and attributes
  # [{"id", "12"}, {"data-open", "false"}].
  #
  # A disallowed attribute name fails the whole marker — see the module doc.
  defp parse_tokens(tokens, config) do
    tokens
    |> Enum.reduce_while({:ok, [], []}, fn token, {:ok, classes, attributes} ->
      case String.split(token, "=", parts: 2) do
        [class] ->
          {:cont, {:ok, [class | classes], attributes}}

        [name, value] ->
          if allowed_attribute?(name, config) do
            {:cont, {:ok, classes, [{name, value} | attributes]}}
          else
            {:halt, :error}
          end
      end
    end)
    |> case do
      {:ok, classes, attributes} -> {:ok, Enum.reverse(classes), Enum.reverse(attributes)}
      :error -> :error
    end
  end

  defp allowed_attribute?(name, config) do
    name in config.allowed_attributes or
      String.starts_with?(name, "data-") or
      String.starts_with?(name, "aria-")
  end

  # OptionParser.split/1 gives shell-like quoting, so both of these work:
  #
  #   title=Introduction
  #   title="Main navigation"
  #
  defp tokenize(rest) do
    case String.trim(rest) do
      "" -> []
      trimmed -> OptionParser.split(trimmed)
    end
  end
end
