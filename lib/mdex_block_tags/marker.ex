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

  """
  @spec parse(String.t(), config()) :: result()
  def parse(literal, config) when is_binary(literal) do
    case Regex.run(@comment, literal) do
      [_, command, _rest] -> classify(String.downcase(command), config)
      nil -> :ordinary
    end
  end

  defp classify("end", _config), do: :close

  defp classify(tag, config) do
    if tag in config.allowed_tags do
      {:open, %__MODULE__{tag: tag, classes: [], attributes: []}}
    else
      :ordinary
    end
  end
end
