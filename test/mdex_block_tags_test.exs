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
  end
end
