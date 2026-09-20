defmodule MDExBlockTags.RewriterTest do
  use ExUnit.Case, async: true

  alias MDExBlockTags.Rewriter

  doctest MDExBlockTags.Rewriter

  @config %{
    allowed_tags: ~w(section nav div),
    allowed_attributes: ~w(id role title)
  }

  defp marker(literal), do: %MDEx.HtmlBlock{literal: literal <> "\n"}
  defp para(text), do: %MDEx.Paragraph{nodes: [%MDEx.Text{literal: text}]}

  defp literals(nodes) do
    Enum.map(nodes, fn
      %MDEx.HtmlBlock{literal: literal} -> String.trim_trailing(literal, "\n")
      %MDEx.Paragraph{nodes: [%MDEx.Text{literal: text}]} -> text
    end)
  end

  describe "run/2" do
    test "wraps the nodes that follow an opening marker" do
      nodes = [marker("<!-- @section intro -->"), para("A")]

      assert literals(Rewriter.run(nodes, @config)) ==
               [~s(<section class="intro">), "A", "</section>"]
    end

    test "opening a block implicitly closes the previous one" do
      nodes = [
        marker("<!-- @section intro -->"),
        para("A"),
        marker("<!-- @nav main -->"),
        para("B")
      ]

      assert literals(Rewriter.run(nodes, @config)) == [
               ~s(<section class="intro">),
               "A",
               "</section>",
               ~s(<nav class="main">),
               "B",
               "</nav>"
             ]
    end

    test "an explicit @end closes the block" do
      nodes = [marker("<!-- @section -->"), para("A"), marker("<!-- @end -->"), para("B")]

      assert literals(Rewriter.run(nodes, @config)) ==
               ["<section>", "A", "</section>", "B"]
    end

    test "a block still open at the end of the document is closed there" do
      nodes = [marker("<!-- @section -->"), para("A")]

      assert literals(Rewriter.run(nodes, @config)) == ["<section>", "A", "</section>"]
    end

    test "an orphan @end is left in place" do
      nodes = [para("A"), marker("<!-- @end -->"), para("B")]

      assert literals(Rewriter.run(nodes, @config)) == ["A", "<!-- @end -->", "B"]
    end

    test "a marker with no content produces an empty wrapper" do
      nodes = [marker("<!-- @section -->"), marker("<!-- @end -->")]

      assert literals(Rewriter.run(nodes, @config)) == ["<section>", "</section>"]
    end

    test "content before the first marker is untouched" do
      nodes = [para("A"), marker("<!-- @section -->"), para("B")]

      assert literals(Rewriter.run(nodes, @config)) ==
               ["A", "<section>", "B", "</section>"]
    end

    test "preserves the order of several children" do
      nodes = [
        marker("<!-- @section -->"),
        para("one"),
        para("two"),
        para("three")
      ]

      assert literals(Rewriter.run(nodes, @config)) ==
               ["<section>", "one", "two", "three", "</section>"]
    end

    test "carries the marker's sourcepos onto the opening node" do
      sourcepos = %MDEx.Sourcepos{start: {7, 1}, end: {7, 26}}
      open = %MDEx.HtmlBlock{literal: "<!-- @section -->\n", sourcepos: sourcepos}

      assert [%MDEx.HtmlBlock{sourcepos: ^sourcepos} | _] = Rewriter.run([open], @config)
    end

    test "never treats a non-HtmlBlock node as a marker" do
      nodes = [para("<!-- @section -->")]

      assert literals(Rewriter.run(nodes, @config)) == ["<!-- @section -->"]
    end

    test "leaves raw HTML that is not a comment alone" do
      nodes = [marker("<div>raw</div>")]

      assert literals(Rewriter.run(nodes, @config)) == ["<div>raw</div>"]
    end

    test "leaves an empty node list alone" do
      assert Rewriter.run([], @config) == []
    end
  end
end
