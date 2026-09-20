defmodule MDExBlockTags.HTMLTest do
  use ExUnit.Case, async: true

  alias MDExBlockTags.HTML
  alias MDExBlockTags.Marker

  doctest MDExBlockTags.HTML

  describe "open_tag/1" do
    test "renders a bare tag without a class attribute" do
      marker = %Marker{tag: "section", classes: [], attributes: []}

      assert HTML.open_tag(marker) == "<section>"
    end

    test "joins classes into a single class attribute" do
      marker = %Marker{tag: "nav", classes: ["main", "blue"], attributes: []}

      assert HTML.open_tag(marker) == ~s(<nav class="main blue">)
    end

    test "renders attributes in order after the class attribute" do
      marker = %Marker{
        tag: "nav",
        classes: ["main"],
        attributes: [{"id", "12"}, {"data-open", "false"}]
      }

      assert HTML.open_tag(marker) == ~s(<nav class="main" id="12" data-open="false">)
    end

    test "escapes class and attribute values" do
      marker = %Marker{
        tag: "section",
        classes: [~s(a"b)],
        attributes: [{"title", "Tom & Jerry"}]
      }

      assert HTML.open_tag(marker) ==
               ~s(<section class="a&quot;b" title="Tom &amp; Jerry">)
    end
  end

  describe "escape_attribute/1" do
    test "escapes the four characters that break an attribute" do
      assert HTML.escape_attribute(~s(a & b " c < d > e)) ==
               "a &amp; b &quot; c &lt; d &gt; e"
    end

    test "does not double-escape an ampersand it just introduced" do
      assert HTML.escape_attribute(~s(")) == "&quot;"
      assert HTML.escape_attribute("&") == "&amp;"
      assert HTML.escape_attribute("&quot;") == "&amp;quot;"
    end
  end

  describe "close_tag/1" do
    test "renders the closing tag" do
      assert HTML.close_tag(%Marker{tag: "section", classes: [], attributes: []}) ==
               "</section>"
    end
  end
end
