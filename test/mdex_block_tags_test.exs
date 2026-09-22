defmodule MDExBlockTagsTest do
  use ExUnit.Case, async: true

  doctest MDExBlockTags

  defp to_html(markdown, plugin_options \\ []) do
    MDEx.to_html!(markdown, plugins: [{MDExBlockTags, plugin_options}])
  end

  describe "attach/2" do
    test "wraps a marked region in the requested element" do
      markdown = """
      <!-- @section introduction -->

      Hello

      <!-- @end -->
      """

      html = to_html(markdown)

      assert html =~ ~s(<section class="introduction">)
      assert html =~ "<p>Hello</p>"
      assert html =~ "</section>"
    end
  end

  describe "safety" do
    test "enables unsafe rendering so the wrappers are emitted" do
      assert to_html("<!-- @section -->\n\nHi\n") =~ "<section>"
    end

    test "does not switch sanitization on when the host left it off" do
      document = MDExBlockTags.attach(MDEx.new(markdown: "<!-- @section -->"))

      assert MDEx.Document.get_option(MDEx.Document.run(document), :sanitize) == nil
    end

    test "extends the allowlist when sanitization is already enabled" do
      html =
        MDEx.to_html!("<!-- @section intro -->\n\nHi\n",
          plugins: [MDExBlockTags],
          sanitize: MDEx.Document.default_sanitize_options()
        )

      assert html =~ ~s(<section class="intro">)
    end

    test "still strips script tags from the source when sanitization is enabled" do
      html =
        MDEx.to_html!("<!-- @section -->\n\n<script>alert(1)</script>\n",
          plugins: [MDExBlockTags],
          sanitize: MDEx.Document.default_sanitize_options()
        )

      refute html =~ "<script>"
    end

    test "extends the allowlist to a custom attribute when sanitization is enabled" do
      html =
        MDEx.to_html!("<!-- @section intro itemprop=name -->\n\nHi\n",
          plugins: [{MDExBlockTags, block_tags_allowed_attributes: ["itemprop"]}],
          sanitize: MDEx.Document.default_sanitize_options()
        )

      assert html =~ ~s(itemprop="name")
    end

    test "does not widen the sanitizer's generic attributes to other elements" do
      markdown = """
      <!-- @section intro -->

      Hi

      <span id="clobber">raw</span>

      <!-- @end -->
      """

      html =
        MDEx.to_html!(markdown,
          plugins: [MDExBlockTags],
          sanitize: MDEx.Document.default_sanitize_options()
        )

      assert html =~ ~s(<section class="intro">)
      # `id` is in the plugin's default allowed_attributes, but must only be
      # permitted on the plugin's own allowed_tags, not on every element in
      # the document — `span` is not one of the plugin's allowed_tags, so it
      # must not gain `id` just because sanitization is enabled (I1:
      # add_generic_attributes previously widened sanitize document-wide).
      refute html =~ ~s(id="clobber")
    end

    test "rejects an attribute name that would inject markup (C1)" do
      literal = "<!-- @section \"data-x onload=alert(1)\" -->\n\nHi\n"

      html = MDEx.to_html!(literal, plugins: [MDExBlockTags])

      # The disallowed attribute name fails the marker closed: no <section>
      # tag is emitted at all, so `onload` can only ever appear as inert text
      # inside the untouched, unsplit HTML comment.
      refute html =~ "<section"
      assert html =~ "<!-- @section \"data-x onload=alert(1)\" -->"
    end

    test "rejects an attribute name that would escape the tag (C1)" do
      literal = "<!-- @section \"data-a><script>alert(1)</script>=x\" -->\n\nHi\n"

      html = MDEx.to_html!(literal, plugins: [MDExBlockTags])

      refute html =~ "<section"
      # The whole payload, including the `<script>` text, stays inert inside
      # a single untouched HTML comment rather than escaping into live markup.
      assert html =~ "<!-- @section \"data-a><script>alert(1)</script>=x\" -->"
    end

    test "does not raise when a marker contains an unbalanced quote (C2)" do
      literal = "<!-- @section title=Tom's -->\n\nHi\n"

      assert MDEx.to_html!(literal, plugins: [MDExBlockTags]) =~ "Tom's"
    end

    test "a disallowed attribute renders the marker as an ordinary comment (end-to-end fail-closed)" do
      markdown = "<!-- @section onclick=alert(1) -->\n\nHi\n"

      html = MDEx.to_html!(markdown, plugins: [MDExBlockTags])

      refute html =~ "<section"
      assert html =~ "<!-- @section onclick=alert(1) -->"
    end
  end

  describe "options" do
    test "honours a custom allowed_tags list" do
      markdown = "<!-- @custom -->\n\nHi\n"

      html = to_html(markdown, block_tags_allowed_tags: ["custom"])

      assert html =~ "<custom>"
    end

    test "rejects a default tag when allowed_tags is overridden" do
      html = to_html("<!-- @section -->\n\nHi\n", block_tags_allowed_tags: ["custom"])

      refute html =~ "<section>"
    end

    test "honours a custom allowed_attributes list" do
      html = to_html("<!-- @section lang=de -->\n\nHi\n", block_tags_allowed_attributes: ["lang"])

      assert html =~ ~s(<section lang="de">)
    end

    test "works when attached as a bare module without options" do
      html = MDEx.to_html!("<!-- @section -->\n\nHi\n", plugins: [MDExBlockTags])

      assert html =~ "<section>"
    end

    test "composes with another plugin" do
      defmodule MarkerPlugin do
        @moduledoc "Test plugin that appends a sentinel node."
        def attach(document, _options \\ []) do
          MDEx.Document.append_steps(document,
            sentinel: fn doc ->
              MDEx.Document.put_node_in_document_root(doc, %MDEx.HtmlBlock{
                literal: "<hr data-sentinel>\n"
              })
            end
          )
        end
      end

      html = MDEx.to_html!("<!-- @section -->\n\nHi\n", plugins: [MDExBlockTags, MarkerPlugin])

      assert html =~ "<section>"
      assert html =~ "data-sentinel"
    end

    test "applies handlers from block_tags_handlers" do
      defmodule ArticleHandler do
        @moduledoc "Renders sections as articles."
        use MDExBlockTags.Handler

        @impl true
        def match(%Marker{tag: "section"}), do: true
        def match(_marker), do: false

        @impl true
        def marker(marker), do: %{marker | tag: "article"}
      end

      html = to_html("<!-- @section -->\n\nHi\n", block_tags_handlers: [ArticleHandler])

      assert html =~ "<article>"
      assert html =~ "</article>"
      refute html =~ "<section>"
    end
  end
end
