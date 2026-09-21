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
          required(:allowed_tags) => [String.t()],
          required(:allowed_attributes) => [String.t()],
          # Callers such as MDExBlockTags.Rewriter carry further keys.
          optional(atom()) => term()
        }

  @type result :: {:open, t()} | :close | :ordinary

  # Only a complete standalone comment counts.
  #
  #   i — <!-- @SECTION --> matches; the command is downcased.
  #   s — the comment may span several lines.
  #
  @comment ~r/\A\s*<!--\s*@([a-z][a-z0-9-]*)((?:(?!-->).)*)-->\s*\z/is

  # HTML/SVG attribute names: a leading letter, underscore or colon, then any
  # number of letters, digits, hyphens, underscores, colons or dots. This
  # excludes whitespace, `>`, `"`, `'`, `=` and `/` — see allowed_attribute?/2.
  @attribute_name ~r/\A[a-zA-Z_:][-a-zA-Z0-9_:.]*\z/

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
    with(
      {:ok, command, rest} <- split_comment(literal),
      {:ok, tokens} <- tokenize(rest),
      {:open, tag} <- classify(String.downcase(command), tokens),
      :ok <- tag_allowed?(tag, config),
      {classes, attributes} <- parse_tokens(tokens),
      :ok <- attributes_allowed?(attributes, config)
    ) do
      {:open, %__MODULE__{tag: tag, classes: classes, attributes: attributes}}
    else
      :close -> :close
      _ -> :ordinary
    end
  end

  # Split the comment string into command and everything after it.
  # The @tag is called command here because it may be @end at this point.
  #
  # iex> MDExBlockTags.Marker.split_comment("<!-- @end -->")
  # {:ok, "end", []}
  @spec split_comment(String.t()) :: {:ok, String.t(), String.t()} | :error
  defp split_comment(literal) do
    case Regex.run(@comment, literal) do
      [_, command, rest] -> {:ok, command, rest}
      _ -> :error
    end
  end

  # OptionParser.split/1 gives shell-like quoting, so both of these work:
  #
  #   title=Introduction
  #   title="Main navigation"
  #
  # It raises RuntimeError on an unbalanced quote (e.g. `title=Tom's`), which
  # would otherwise propagate out of this library and crash the caller's
  # render for a markdown typo. Rescue it into the same fail-closed :error
  # that an invalid attribute name produces.
  @spec tokenize(String.t()) :: {:ok, [String.t()]} | :error
  defp tokenize(rest) do
    case String.trim(rest) do
      "" -> {:ok, []}
      trimmed -> {:ok, OptionParser.split(trimmed)}
    end
  rescue
    RuntimeError -> :error
  end

  defp classify("end", []), do: :close
  defp classify("end", _attributes), do: :ordinary
  defp classify(tag, _attributes), do: {:open, tag}

  defp tag_allowed?("end", _config), do: :ok

  defp tag_allowed?(tag, config) do
    if tag in config.allowed_tags, do: :ok, else: :forbidden
  end

  # Bare tokens are CSS classes; key=value tokens are HTML attributes.
  #
  #   @nav main blue id=12 data-open=false
  #
  # becomes classes ["main", "blue"] and attributes
  # [{"id", "12"}, {"data-open", "false"}].
  #
  # A disallowed attribute name fails the whole marker — see the module doc.
  defp parse_tokens(tokens) do
    {classes, attributes} =
      tokens
      |> Enum.reduce({[], []}, fn token, acc ->
        String.split(token, "=", parts: 2) |> parse_token(acc)
      end)

    {Enum.reverse(classes), Enum.reverse(attributes)}
  end

  defp parse_token([name, value], {classes, attributes}) do
    {classes, [{name, value} | attributes]}
  end

  defp parse_token([class], {classes, attributes}) do
    {[class | classes], attributes}
  end

  defp attributes_allowed?(attributes, config) do
    if Enum.all?(attributes, fn {name, _value} ->
         allowed_attribute?(name, config)
       end) do
      :ok
    else
      :forbidden
    end
  end

  # A character-set check runs first: it is what actually constrains what can
  # reach the serialised tag, since it applies before either the exact-match
  # or the data-/aria- prefix check below. Without it, `starts_with?` only
  # constrains the first five characters of `name` and anything after that —
  # including whitespace, `>`, `"`, `'` and `=` — would reach
  # `HTML.attributes_string/1`.
  defp allowed_attribute?(name, config) do
    Regex.match?(@attribute_name, name) and
      (name in config.allowed_attributes or
         String.starts_with?(name, "data-") or
         String.starts_with?(name, "aria-"))
  end
end
