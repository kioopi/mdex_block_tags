defmodule MDExBlockTags.MarkerTest do
  use ExUnit.Case, async: true

  alias MDExBlockTags.Marker

  doctest MDExBlockTags.Marker

  @config [
    allowed_tags: ~w(section nav div),
    allowed_attributes: ~w(id role title)
  ]

  def classify(literal, config \\ @config) do
    Marker.classify(%MDEx.HtmlBlock{literal: literal}, config)
  end

  describe "parse/1 comment parsing" do
    test "recognises a bare opening marker" do
      assert Marker.parse("<!-- @section -->") ==
               {:ok, %Marker{tag: "section", classes: [], attributes: []}}
    end

    test "leaves an ordinary comment alone" do
      assert Marker.parse("<!-- TODO: rewrite this -->") == :invalid
    end

    test "recognises the closing marker" do
      assert Marker.parse("<!-- @end -->") ==
               {:ok, %Marker{tag: "end", classes: [], attributes: []}}
    end

    test "matches case-insensitively and downcases the tag" do
      assert Marker.parse("<!-- @SECTION -->") ==
               {:ok, %Marker{tag: "section", classes: [], attributes: []}}
    end

    test "matches a comment spanning several lines" do
      assert Marker.parse("<!--\n  @section\n-->") ==
               {:ok, %Marker{tag: "section", classes: [], attributes: []}}
    end

    test "tolerates whitespace around the comment" do
      assert Marker.parse("\n  <!-- @section -->  \n") ==
               {:ok, %Marker{tag: "section", classes: [], attributes: []}}
    end

    test "ignores a comment that is not standalone" do
      assert Marker.parse("text <!-- @section -->") == :invalid
    end

    test "does not swallow a following comment inside the same HTML block" do
      # Previously the lazy `.*?` + `\z` regex let this parse as {:open, ...}
      # with a corrupted class list ["--><!--", "@end"], silently eating the
      # @end marker. Two comments squashed into one HtmlBlock literal are not
      # a single standalone marker, so the correct, safe outcome is :ordinary
      # — not attempting to split them into two markers here.
      assert Marker.parse("<!-- @section --><!-- @end -->") == :invalid
    end
  end

  describe "parse/1 token parsing" do
    test "treats a bare token as a CSS class" do
      assert Marker.parse("<!-- @section intro -->") ==
               {:ok, %Marker{tag: "section", classes: ["intro"], attributes: []}}
    end

    test "treats a key=value token as an attribute" do
      assert Marker.parse("<!-- @section id=12 -->") ==
               {:ok, %Marker{tag: "section", classes: [], attributes: [{"id", "12"}]}}
    end

    test "keeps multiple classes in source order" do
      assert Marker.parse("<!-- @nav main blue -->") ==
               {:ok, %Marker{tag: "nav", classes: ["main", "blue"], attributes: []}}
    end

    test "keeps classes and attributes in source order" do
      assert Marker.parse("<!-- @nav main id=12 blue role=navigation -->") ==
               {:ok,
                %Marker{
                  tag: "nav",
                  classes: ["main", "blue"],
                  attributes: [{"id", "12"}, {"role", "navigation"}]
                }}
    end

    test "supports quoted attribute values containing spaces" do
      assert Marker.parse(~s(<!-- @nav title="Main navigation" -->)) ==
               {:ok, %Marker{tag: "nav", classes: [], attributes: [{"title", "Main navigation"}]}}
    end

    test "allows any data- attribute" do
      assert Marker.parse("<!-- @section data-open=false -->") ==
               {:ok, %Marker{tag: "section", classes: [], attributes: [{"data-open", "false"}]}}
    end

    test "allows any aria- attribute" do
      assert Marker.parse("<!-- @nav aria-label=Menu -->") ==
               {:ok, %Marker{tag: "nav", classes: [], attributes: [{"aria-label", "Menu"}]}}
    end

    test "splits on the first = only" do
      assert Marker.parse("<!-- @section data-x=a=b -->") ==
               {:ok, %Marker{tag: "section", classes: [], attributes: [{"data-x", "a=b"}]}}
    end

    test "accepts an empty attribute value" do
      assert Marker.parse("<!-- @section id= -->") ==
               {:ok, %Marker{tag: "section", classes: [], attributes: [{"id", ""}]}}
    end
  end

  describe "classify/2 comment" do
    test "leaves an ordinary comment alone" do
      assert classify("<!-- TODO: rewrite this -->", @config) == :ordinary
    end

    test "recognises the closing marker" do
      assert classify("<!-- @end -->", @config) == :close
    end

    test "rejects a command that is not an allowed tag" do
      assert classify("<!-- @script -->", @config) == :ordinary
    end

    test "ignores a comment that is not standalone" do
      assert classify("text <!-- @section -->", @config) == :ordinary
    end

    test "does not swallow a following comment inside the same HTML block" do
      # Previously the lazy `.*?` + `\z` regex let this parse as {:open, ...}
      # with a corrupted class list ["--><!--", "@end"], silently eating the
      # @end marker. Two comments squashed into one HtmlBlock literal are not
      # a single standalone marker, so the correct, safe outcome is :ordinary
      # — not attempting to split them into two markers here.
      assert classify("<!-- @section --><!-- @end -->", @config) == :ordinary
    end

    test "respects a custom allowed_tags list" do
      config = Keyword.put(@config, :allowed_tags, ["custom"])

      assert classify("<!-- @section -->", config) == :ordinary

      assert classify("<!-- @custom -->", config) ==
               {:open, %Marker{tag: "custom", classes: [], attributes: []}}
    end
  end

  describe "classify/2 tokens" do
    test "respects a custom allowed_attributes list" do
      config = Keyword.put(@config, :allowed_attributes, ["lang"])

      assert classify("<!-- @section lang=de -->", config) ==
               {:open, %Marker{tag: "section", classes: [], attributes: [{"lang", "de"}]}}

      assert classify("<!-- @section id=12 -->", config) == :ordinary
    end

    test "treats @end with tokens as an ordinary comment" do
      assert classify("<!-- @end extra -->", @config) == :ordinary
    end

    test "rejects an attribute name containing a space (data- prefix injection)" do
      literal = "<!-- @section \"data-x onload=alert(1)\" -->"
      assert classify(literal, @config) == :ordinary
    end

    test "rejects an attribute name containing '>' (tag escape)" do
      literal = "<!-- @section \"data-a><script>alert(1)</script>=x\" -->"
      assert classify(literal, @config) == :ordinary
    end

    test "does not raise on an unbalanced quote in the marker" do
      assert classify("<!-- @section title=Tom's -->", @config) == :ordinary
    end

    test "degrades the whole marker when an attribute is not allowed" do
      assert classify("<!-- @section intro onclick=alert(1) -->", @config) == :ordinary
    end
  end
end
