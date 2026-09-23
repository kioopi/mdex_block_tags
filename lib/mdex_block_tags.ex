defmodule MDExBlockTags do
  alias MDEx.Document
  alias MDExBlockTags.Marker
  alias MDExBlockTags.Rewriter

  @options [
    allowed_tags: :block_tags_allowed_tags,
    allowed_attributes: :block_tags_allowed_attributes,
    handlers: :block_tags_handlers,
    classifier: :block_tags_classifier,
    renderer: :block_tags_renderer
  ]

  @type options :: Rewriter.options()

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
      Defaults to `#{inspect(Marker.options()[:allowed_tags])}`.

    * `:block_tags_allowed_attributes` — attribute names permitted in addition
      to anything prefixed `data-` or `aria-`. Defaults to
      `#{inspect(Marker.options()[:allowed_attributes])}`.

    * `:block_tags_handlers` — `MDExBlockTags.Handler` modules that customise
      the output for the blocks they match, applied in list order. Defaults
      to `[]`.

    * `:block_tags_renderer` — Anonymous function that replaces the default
      renderer, `MDExBlockTags.Handlers.render/4`.
      Takes `Marker.t()`, `[MDEx.Document.md_node]`, `MDEx.Sourcepos.t()` and returns
      `[MDEx.Document.md_node]`.
      This can be used to manipulate the AST of the MDEx Document inside a block.
      Use with caution! `block_tags_handlers` are not applied anymore.
      Prefer using a handler with `content/2`.

    * `:block_tags_classifier` — Anonymous function that replaces the default
      classifier, `MDExBlockTags.Marker.classify/2`.
      Takes (MDEx.Document.md_node) returns `{:open, Marker.t()}` or `:close` or
      `:ordinary`.
      This can be used to start blocks on other elements than HTML comments or
      change the parsing of the comments.
      Use with caution! This does not apply `:block_tags_allowed_tags` or
      `:block_tags_allowed_attributes`.

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
    |> Document.register_options(Keyword.values(@options))
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
        opts = marker_defaults(document)
        tags = opts[:allowed_tags]
        attributes = Enum.uniq(["class" | opts[:allowed_attributes]])

        Document.put_sanitize_options(document,
          add_tags: tags,
          add_tag_attributes: Map.new(tags, &{&1, attributes}),
          # ammonia has no per-tag prefix option, so add_generic_attribute_prefixes
          # necessarily widens data-*/aria-* to every tag in the document, not
          # just this plugin's own — see the README's Safety section.
          add_generic_attribute_prefixes: ["data-", "aria-"]
        )
    end
  end

  defp marker_defaults(document) do
    document
    |> options(Keyword.take(@options, Marker.options(:keys)))
    |> Keyword.validate!(Marker.options())
  end

  defp rewrite(%Document{nodes: nodes} = document) do
    %{document | nodes: Rewriter.run(nodes, options(document))}
  end

  # Get options from MDEx.Document to pass to Rewriter.run/2
  @spec options(MDEx.Document.t(), keyword()) :: options()
  defp options(%MDEx.Document{} = document, opts \\ @options) do
    opts
    |> Enum.reduce([], fn {name, in_doc}, opts ->
      case Document.get_option(document, in_doc) do
        nil -> opts
        opt -> [{name, opt} | opts]
      end
    end)
  end
end
