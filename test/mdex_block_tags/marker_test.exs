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

    test "respects a custom allowed_tags list" do
      config = %{@config | allowed_tags: ["custom"]}

      assert Marker.parse("<!-- @section -->", config) == :ordinary

      assert Marker.parse("<!-- @custom -->", config) ==
               {:open, %Marker{tag: "custom", classes: [], attributes: []}}
    end
  end
end
