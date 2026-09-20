defmodule MDExBlockTags.MarkerTest do
  use ExUnit.Case, async: true

  alias MDExBlockTags.Marker

  doctest MDExBlockTags.Marker

  @config %{
    allowed_tags: ~w(section nav div),
    allowed_attributes: ~w(id role title)
  }

  describe "parse/2 comment recognition" do
    test "recognises a bare opening marker" do
      assert Marker.parse("<!-- @section -->", @config) ==
               {:open, %Marker{tag: "section", classes: [], attributes: []}}
    end

    test "leaves an ordinary comment alone" do
      assert Marker.parse("<!-- TODO: rewrite this -->", @config) == :ordinary
    end

    test "recognises the closing marker" do
      assert Marker.parse("<!-- @end -->", @config) == :close
    end

    test "rejects a command that is not an allowed tag" do
      assert Marker.parse("<!-- @script -->", @config) == :ordinary
    end

    test "matches case-insensitively and downcases the tag" do
      assert Marker.parse("<!-- @SECTION -->", @config) ==
               {:open, %Marker{tag: "section", classes: [], attributes: []}}
    end

    test "matches a comment spanning several lines" do
      assert Marker.parse("<!--\n  @section\n-->", @config) ==
               {:open, %Marker{tag: "section", classes: [], attributes: []}}
    end

    test "tolerates whitespace around the comment" do
      assert Marker.parse("\n  <!-- @section -->  \n", @config) ==
               {:open, %Marker{tag: "section", classes: [], attributes: []}}
    end

    test "ignores a comment that is not standalone" do
      assert Marker.parse("text <!-- @section -->", @config) == :ordinary
    end

    test "does not swallow a following comment inside the same HTML block" do
      # Previously the lazy `.*?` + `\z` regex let this parse as {:open, ...}
      # with a corrupted class list ["--><!--", "@end"], silently eating the
      # @end marker. Two comments squashed into one HtmlBlock literal are not
      # a single standalone marker, so the correct, safe outcome is :ordinary
      # — not attempting to split them into two markers here.
      assert Marker.parse("<!-- @section --><!-- @end -->", @config) == :ordinary
    end

    test "respects a custom allowed_tags list" do
      config = %{@config | allowed_tags: ["custom"]}

      assert Marker.parse("<!-- @section -->", config) == :ordinary

      assert Marker.parse("<!-- @custom -->", config) ==
               {:open, %Marker{tag: "custom", classes: [], attributes: []}}
    end
  end

  describe "parse/2 token parsing" do
    test "treats a bare token as a CSS class" do
      assert Marker.parse("<!-- @section intro -->", @config) ==
               {:open, %Marker{tag: "section", classes: ["intro"], attributes: []}}
    end

    test "treats a key=value token as an attribute" do
      assert Marker.parse("<!-- @section id=12 -->", @config) ==
               {:open, %Marker{tag: "section", classes: [], attributes: [{"id", "12"}]}}
    end

    test "degrades the whole marker when an attribute is not allowed" do
      assert Marker.parse("<!-- @section intro onclick=alert(1) -->", @config) == :ordinary
    end

    test "keeps multiple classes in source order" do
      assert Marker.parse("<!-- @nav main blue -->", @config) ==
               {:open, %Marker{tag: "nav", classes: ["main", "blue"], attributes: []}}
    end

    test "keeps classes and attributes in source order" do
      assert Marker.parse("<!-- @nav main id=12 blue role=navigation -->", @config) ==
               {:open,
                %Marker{
                  tag: "nav",
                  classes: ["main", "blue"],
                  attributes: [{"id", "12"}, {"role", "navigation"}]
                }}
    end

    test "supports quoted attribute values containing spaces" do
      assert Marker.parse(~s(<!-- @nav title="Main navigation" -->), @config) ==
               {:open,
                %Marker{tag: "nav", classes: [], attributes: [{"title", "Main navigation"}]}}
    end

    test "allows any data- attribute" do
      assert Marker.parse("<!-- @section data-open=false -->", @config) ==
               {:open, %Marker{tag: "section", classes: [], attributes: [{"data-open", "false"}]}}
    end

    test "allows any aria- attribute" do
      assert Marker.parse("<!-- @nav aria-label=Menu -->", @config) ==
               {:open, %Marker{tag: "nav", classes: [], attributes: [{"aria-label", "Menu"}]}}
    end

    test "splits on the first = only" do
      assert Marker.parse("<!-- @section data-x=a=b -->", @config) ==
               {:open, %Marker{tag: "section", classes: [], attributes: [{"data-x", "a=b"}]}}
    end

    test "accepts an empty attribute value" do
      assert Marker.parse("<!-- @section id= -->", @config) ==
               {:open, %Marker{tag: "section", classes: [], attributes: [{"id", ""}]}}
    end

    test "respects a custom allowed_attributes list" do
      config = %{@config | allowed_attributes: ["lang"]}

      assert Marker.parse("<!-- @section lang=de -->", config) ==
               {:open, %Marker{tag: "section", classes: [], attributes: [{"lang", "de"}]}}

      assert Marker.parse("<!-- @section id=12 -->", config) == :ordinary
    end

    test "treats @end with tokens as an ordinary comment" do
      assert Marker.parse("<!-- @end extra -->", @config) == :ordinary
    end

    test "rejects an attribute name containing a space (data- prefix injection)" do
      literal = "<!-- @section \"data-x onload=alert(1)\" -->"
      assert Marker.parse(literal, @config) == :ordinary
    end

    test "rejects an attribute name containing '>' (tag escape)" do
      literal = "<!-- @section \"data-a><script>alert(1)</script>=x\" -->"
      assert Marker.parse(literal, @config) == :ordinary
    end

    test "does not raise on an unbalanced quote in the marker" do
      assert Marker.parse("<!-- @section title=Tom's -->", @config) == :ordinary
    end
  end
end
