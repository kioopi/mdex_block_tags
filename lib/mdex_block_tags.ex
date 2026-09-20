defmodule MDExBlockTags do
  @default_allowed_tags ~w(section nav article aside main header footer div)
  @default_allowed_attributes ~w(id role title)

  @moduledoc """
  An [MDEx](https://hexdocs.pm/mdex) plugin that adds semantic block
  annotations to Markdown using HTML comments.

      <!-- @section introduction -->

      Content

      <!-- @nav main blue id=12 data-open=false -->

      Navigation content

      <!-- @end -->

  produces:

      <section class="introduction">
        ...
      </section>

      <nav class="main blue" id="12" data-open="false">
        ...
      </nav>

  Bare tokens become CSS classes; `key=value` tokens become HTML attributes.
  Opening a block implicitly closes the current one, and a block still open at
  the end of the document is closed there.

  ## Usage

      MDEx.to_html!(markdown, plugins: [MDExBlockTags])

      MDEx.new(plugins: [{MDExBlockTags, block_tags_allowed_tags: ~w(section aside)}])

      MDEx.new() |> MDExBlockTags.attach()

  ## Options

    * `:block_tags_allowed_tags` — the commands that may open a block.
      Defaults to `#{inspect(@default_allowed_tags)}`.

    * `:block_tags_allowed_attributes` — attribute names permitted in addition
      to anything prefixed `data-` or `aria-`. Defaults to
      `#{inspect(@default_allowed_attributes)}`.

  A marker naming any other attribute is left in the document as an ordinary
  comment rather than being rendered with the attribute stripped.

  ## Safety

  The wrappers this plugin emits are `MDEx.HtmlBlock` nodes, and MDEx only
  renders those when the `:unsafe` render option is set. `attach/2` therefore
  sets `unsafe: true` on your behalf — which also means any other raw HTML in
  your Markdown will render.

  Sanitization is left to you. MDEx disables it by default, and this plugin
  will not turn it on behind your back. If it *is* enabled, `attach/2` extends
  its allowlist so this plugin's own output survives:

      MDEx.to_html!(markdown,
        plugins: [MDExBlockTags],
        sanitize: MDEx.Document.default_sanitize_options()
      )

  For untrusted Markdown, enabling `:sanitize` is the recommended posture.
  """

  alias MDEx.Document
  alias MDExBlockTags.Rewriter

  @doc """
  Attaches the plugin to an `MDEx.Document`.

  ## Examples

      iex> markdown = "<!-- @section intro -->\\n\\nHi\\n"
      iex> html = MDEx.to_html!(markdown, plugins: [MDExBlockTags])
      iex> String.contains?(html, ~s(<section class="intro">))
      true

  """
  @spec attach(Document.t(), keyword()) :: Document.t()
  def attach(document, options \\ []) do
    document
    |> Document.register_options([
      :block_tags_allowed_tags,
      :block_tags_allowed_attributes
    ])
    |> Document.put_options(options)
    |> Document.append_steps(
      block_tags_enable_unsafe: &enable_unsafe/1,
      block_tags_extend_sanitize: &extend_sanitize/1,
      block_tags_rewrite: &rewrite/1
    )
  end

  # Synthetic HtmlBlock nodes need raw HTML rendering.
  defp enable_unsafe(document) do
    Document.put_render_options(document, unsafe: true)
  end

  # Do not make unsafe: true mean "anything goes" — but do not switch
  # sanitization on for a host that deliberately left it off either.
  defp extend_sanitize(document) do
    case Document.get_option(document, :sanitize) do
      nil ->
        document

      _enabled ->
        cfg = config(document)
        attributes = Enum.uniq(["class" | cfg.allowed_attributes])

        Document.put_sanitize_options(document,
          add_tags: cfg.allowed_tags,
          add_tag_attributes: Map.new(cfg.allowed_tags, &{&1, attributes}),
          # ammonia has no per-tag prefix option, so add_generic_attribute_prefixes
          # necessarily widens data-*/aria-* to every tag in the document, not
          # just this plugin's own — see the README's Safety section.
          add_generic_attribute_prefixes: ["data-", "aria-"]
        )
    end
  end

  defp rewrite(%Document{nodes: nodes} = document) do
    %{document | nodes: Rewriter.run(nodes, config(document))}
  end

  defp config(document) do
    %{
      allowed_tags:
        Document.get_option(document, :block_tags_allowed_tags, @default_allowed_tags),
      allowed_attributes:
        Document.get_option(
          document,
          :block_tags_allowed_attributes,
          @default_allowed_attributes
        )
    }
  end
end
