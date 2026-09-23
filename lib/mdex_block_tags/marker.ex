defmodule MDExBlockTags.Marker do
  @default_allowed_tags ~w(section nav article aside main header footer div)
  @default_allowed_attributes ~w(id role title)
  @options [
    allowed_tags: @default_allowed_tags,
    allowed_attributes: @default_allowed_attributes
  ]

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

  ## The struct

  `parse/2` returns a `%MDExBlockTags.Marker{}` for a recognised opening
  marker. Its fields:

    * `tag` — the command name, e.g. `"section"`.
    * `classes` — the bare tokens, in order, e.g. `["main", "blue"]`.
      Defaults to `[]`.
    * `attributes` — the `key=value` tokens as `{name, value}` tuples, e.g.
      `[{"id", "12"}]`. Defaults to `[]`.

  A handler matches on and builds this struct directly — see
  `MDExBlockTags.Handler`.
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
  @type classification :: {:open, t()} | :close | :ordinary

  @type classify_option :: {:allowed_tags, [String.t()]} | {:allowed_attributes, [String.t()]}
  @type options :: [classify_option()]

  # Only a complete standalone comment counts.
  #
  #   i — <!-- @SECTION --> matches; the command is downcased.
  #   s — the comment may span several lines.
  #
  @comment ~r/\A\s*<!--\s*@([a-z][a-z0-9-]*)((?:(?!-->).)*)-->\s*\z/is

  # HTML/SVG attribute names: a leading letter, underscore or colon, then any
  # number of letters, digits, hyphens, underscores, colons or dots. This
  # excludes whitespace, `>`, `"`, `'`, `=` and `/` — see allowed?/2.
  @attribute_name ~r/\A[a-zA-Z_:][-a-zA-Z0-9_:.]*\z/

  @doc """
  Returns the list of options that `classify/2` takes as second parameter.

  ## Examples

    iex> MDExBlockTags.Marker.options()
    [
      allowed_tags: ["section", "nav", "article", "aside", "main", "header", "footer", "div"],
      allowed_attributes: ["id", "role", "title"]
    ]

    iex> MDExBlockTags.Marker.options(:keys)
    [:allowed_tags, :allowed_attributes]
  """
  @spec options(:keys) :: [atom()]
  def options(:keys), do: Keyword.keys(@options)
  @spec options() :: options()
  def options, do: @options

  @doc """
  Classifies a MDEx node.

  ## Examples

      iex> block = %MDEx.HtmlBlock{literal: "<!-- @section -->"}
      iex> MDExBlockTags.Marker.classify(block, allowed_tags: ["section"], allowed_attributes: ["id"])
      {:open, %MDExBlockTags.Marker{tag: "section", classes: [], attributes: []}}

      iex> options = [allowed_tags: ["nav"], allowed_attributes: ["id"]]
      iex> block = %MDEx.HtmlBlock{literal: ~s(<!-- @nav main blue id=12 -->)}
      iex> MDExBlockTags.Marker.classify(block, options)
      {:open,
       %MDExBlockTags.Marker{
         tag: "nav",
         classes: ["main", "blue"],
         attributes: [{"id", "12"}]
       }}

      iex> block = %MDEx.HtmlBlock{literal: ~s(<!-- @end -->)}
      iex> MDExBlockTags.Marker.classify(block)
      :close

      iex> block = %MDEx.HtmlBlock{literal: ~s(<!-- TODO: rewrite this -->)}
      iex> MDExBlockTags.Marker.classify(block)
      :ordinary
  """

  @spec classify(MDEx.Document.md_node(), options()) :: classification()

  def classify(md_node, opts \\ [])

  def classify(%MDEx.HtmlBlock{literal: literal}, opts) do
    opts = Keyword.validate!(opts, @options)

    case parse(literal) do
      {:ok, %__MODULE__{tag: "end", attributes: [], classes: []}} ->
        :close

      {:ok, %__MODULE__{tag: "end"}} ->
        :ordinary

      {:ok, %__MODULE__{tag: tag, attributes: attributes} = marker} ->
        with true <- tag in opts[:allowed_tags],
             true <- Enum.all?(attributes, &allowed?(&1, opts[:allowed_attributes])) do
          {:open, marker}
        else
          _ -> :ordinary
        end

      _ ->
        :ordinary
    end
  end

  def classify(_, _), do: :ordinary

  @doc """
  Parses a HTML comment.

  ## Examples

      iex> MDExBlockTags.Marker.parse("<!-- @section -->")
      {:ok, %MDExBlockTags.Marker{tag: "section", classes: [], attributes: []}}

      iex> MDExBlockTags.Marker.parse(~s(<!-- @nav main blue id=12 -->))
      {:ok,
       %MDExBlockTags.Marker{
         tag: "nav",
         classes: ["main", "blue"],
         attributes: [{"id", "12"}]
       }}

      iex> MDExBlockTags.Marker.parse(~s(<!-- @end -->))
      {:ok, %MDExBlockTags.Marker{tag: "end", classes: [], attributes: []}}

      iex> MDExBlockTags.Marker.parse("<!-- TODO: rewrite this -->")
      :invalid
  """
  @spec parse(String.t()) :: {:ok, t()} | :invalid
  def parse(literal) when is_binary(literal) do
    with(
      {:ok, command, rest} <- split_comment(literal),
      {:ok, tokens} <- tokenize(rest),
      tag <- String.downcase(command),
      {classes, attributes} <- parse_tokens(tokens)
    ) do
      {:ok, %__MODULE__{tag: tag, classes: classes, attributes: attributes}}
    else
      _ -> :invalid
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

  # A character-set check runs first: it is what actually constrains what can
  # reach the serialised tag, since it applies before either the exact-match
  # or the data-/aria- prefix check below. Without it, `starts_with?` only
  # constrains the first five characters of `name` and anything after that —
  # including whitespace, `>`, `"`, `'` and `=` — would reach
  # `HTML.attributes_string/1`.
  defp allowed?({name, _val}, allowed_attributes) do
    Regex.match?(@attribute_name, name) and
      (name in allowed_attributes or
         String.starts_with?(name, "data-") or
         String.starts_with?(name, "aria-"))
  end
end
