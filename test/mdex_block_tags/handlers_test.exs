defmodule MDExBlockTags.HandlersTest do
  use ExUnit.Case, async: true

  alias MDExBlockTags.Handlers
  alias MDExBlockTags.Marker

  doctest MDExBlockTags.Handlers

  defmodule AddClass do
    @moduledoc "Adds the class `extra` to sections."
    use MDExBlockTags.Handler

    @impl true
    def match(%Marker{tag: "section"}), do: true
    def match(_marker), do: false

    @impl true
    def marker(marker), do: %{marker | classes: marker.classes ++ ["extra"]}
  end

  defmodule NeverMatches do
    @moduledoc "Matches nothing; raises if any other callback is reached."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: false

    @impl true
    def marker(_marker), do: raise("marker/1 must not be called")

    @impl true
    def add(_marker), do: raise("add/1 must not be called")

    @impl true
    def wrap(_marker), do: raise("wrap/1 must not be called")

    @impl true
    def content(_marker, _nodes), do: raise("content/2 must not be called")
  end

  defmodule OnlyMatchHandler do
    @moduledoc "Implements only match/1; every other callback uses its default."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true
  end

  defmodule ToArticle do
    @moduledoc "Renders sections as articles."
    use MDExBlockTags.Handler

    @impl true
    def match(%Marker{tag: "section"}), do: true
    def match(_marker), do: false

    @impl true
    def marker(marker), do: %{marker | tag: "article"}
  end

  defmodule OnArticle do
    @moduledoc "Adds the class `seen` to articles."
    use MDExBlockTags.Handler

    @impl true
    def match(%Marker{tag: "article"}), do: true
    def match(_marker), do: false

    @impl true
    def marker(marker), do: %{marker | classes: ["seen"]}
  end

  defmodule AddEverywhere do
    @moduledoc "Adds a string at every position."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(_marker), do: [after: "after", end: "end", start: "start", before: "before"]
  end

  defmodule AddBareString do
    @moduledoc "Returns a bare string from add/1."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(_marker), do: "bare"
  end

  defmodule AddNode do
    @moduledoc "Returns an MDEx node from add/1, bare and keyed."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(%Marker{classes: ["keyed"]}),
      do: [end: %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "node"}]}]

    def add(_marker), do: %MDEx.Paragraph{nodes: [%MDEx.Text{literal: "node"}]}
  end

  defmodule AddRepeated do
    @moduledoc "Adds two entries at the same position."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(_marker), do: [start: "one", start: "two"]
  end

  defmodule WrapBoth do
    @moduledoc "Adds one inner and one outer wrapper, plus content at every position."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(_marker), do: [before: "before", start: "start", end: "end", after: "after"]

    @impl true
    def wrap(_marker), do: [inner: %Marker{tag: "div"}, outer: %Marker{tag: "aside"}]
  end

  defmodule WrapBare do
    @moduledoc "Returns a bare marker from wrap/1."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def wrap(_marker), do: %Marker{tag: "aside"}
  end

  defmodule WrapRepeated do
    @moduledoc "Adds two inner and two outer wrappers."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def wrap(_marker) do
      [
        inner: %Marker{tag: "div", classes: ["i1"]},
        inner: %Marker{tag: "div", classes: ["i2"]},
        outer: %Marker{tag: "div", classes: ["o1"]},
        outer: %Marker{tag: "div", classes: ["o2"]}
      ]
    end
  end

  defmodule WrapEscaped do
    @moduledoc "Wraps in a marker whose values need escaping."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def wrap(_marker), do: [inner: %Marker{tag: "div", attributes: [{"title", ~s(a"b)}]}]
  end

  defmodule CountChildren do
    @moduledoc "Replaces the children with a count of what it received, and adds at :start."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(_marker), do: [start: "start"]

    @impl true
    def content(_marker, nodes) do
      [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "saw #{length(nodes)}"}]}]
    end
  end

  @section %Marker{tag: "section"}
  @sourcepos %MDEx.Sourcepos{start: {3, 1}, end: {3, 20}}

  defp para(text), do: %MDEx.Paragraph{nodes: [%MDEx.Text{literal: text}]}

  defp render(handlers, marker \\ @section, children \\ [para("content")]) do
    Handlers.render(marker, children, @sourcepos, handlers)
  end

  defp literals(nodes) do
    Enum.map(nodes, fn
      %MDEx.HtmlBlock{literal: literal} -> String.trim_trailing(literal, "\n")
      %MDEx.Paragraph{nodes: [%MDEx.Text{literal: text}]} -> text
    end)
  end

  describe "render/4 without handlers" do
    test "wraps the children in the marker's tags" do
      assert literals(render([])) == ["<section>", "content", "</section>"]
    end

    test "carries the sourcepos onto the opening tag only" do
      [open, _content, close] = render([])

      assert open.sourcepos == @sourcepos
      assert close.sourcepos == %MDEx.Sourcepos{}
    end

    test "a handler implementing only match/1 renders exactly like no handlers" do
      assert render([OnlyMatchHandler]) == render([])
    end
  end

  describe "match/1 and marker/1" do
    test "marker/1 changes the opening tag" do
      assert literals(render([AddClass])) ==
               [~s(<section class="extra">), "content", "</section>"]
    end

    test "a handler that does not match leaves the block alone" do
      assert literals(render([NeverMatches])) == ["<section>", "content", "</section>"]
    end

    test "marker/1 changing the tag changes the closing tag too" do
      assert literals(render([ToArticle])) == ["<article>", "content", "</article>"]
    end

    test "each handler sees the marker as the previous one left it" do
      assert literals(render([ToArticle, OnArticle])) ==
               [~s(<article class="seen">), "content", "</article>"]

      assert literals(render([OnArticle, ToArticle])) ==
               ["<article>", "content", "</article>"]
    end
  end

  describe "add/1" do
    test "places content at each position" do
      assert literals(render([AddEverywhere])) ==
               ["before", "<section>", "start", "content", "end", "</section>", "after"]
    end

    test "turns a string into an HtmlBlock" do
      assert %MDEx.HtmlBlock{literal: "before\n"} in render([AddEverywhere])
    end

    test "a bare string goes to :start" do
      assert literals(render([AddBareString])) ==
               ["<section>", "bare", "content", "</section>"]
    end

    test "inserts an MDEx node as-is, bare (at :start) or keyed" do
      assert literals(render([AddNode])) ==
               ["<section>", "node", "content", "</section>"]

      assert literals(render([AddNode], %Marker{tag: "section", classes: ["keyed"]})) ==
               [~s(<section class="keyed">), "content", "node", "</section>"]
    end

    test "repeated positions keep their order" do
      assert literals(render([AddRepeated])) ==
               ["<section>", "one", "two", "content", "</section>"]
    end
  end

  describe "wrap/1" do
    test "lays out one handler's wrappers and additions as in the spec" do
      assert literals(render([WrapBoth])) == [
               "before",
               "<aside>",
               "<section>",
               "<div>",
               "start",
               "content",
               "end",
               "</div>",
               "</section>",
               "</aside>",
               "after"
             ]
    end

    test "a bare marker goes to :outer" do
      assert literals(render([WrapBare])) ==
               ["<aside>", "<section>", "content", "</section>", "</aside>"]
    end

    test "repeated wrappers nest with the first closest to the children" do
      assert literals(render([WrapRepeated])) == [
               ~s(<div class="o2">),
               ~s(<div class="o1">),
               "<section>",
               ~s(<div class="i2">),
               ~s(<div class="i1">),
               "content",
               "</div>",
               "</div>",
               "</section>",
               "</div>",
               "</div>"
             ]
    end

    test "escapes wrapper attribute values" do
      assert ~s(<div title="a&quot;b">) in literals(render([WrapEscaped]))
    end
  end

  describe "content/2" do
    test "replaces the children, before this handler's own additions" do
      assert literals(render([CountChildren])) ==
               ["<section>", "start", "saw 1", "</section>"]
    end
  end

  defmodule LayerA do
    @moduledoc "Adds an A-labelled item at every position."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(_marker), do: [before: "A.before", start: "A.start", end: "A.end", after: "A.after"]

    @impl true
    def wrap(_marker), do: [inner: %Marker{tag: "a-inner"}, outer: %Marker{tag: "a-outer"}]
  end

  defmodule LayerB do
    @moduledoc "Adds a B-labelled item at every position."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(_marker), do: [before: "B.before", start: "B.start", end: "B.end", after: "B.after"]

    @impl true
    def wrap(_marker), do: [inner: %Marker{tag: "b-inner"}, outer: %Marker{tag: "b-outer"}]
  end

  defmodule BadMatch do
    @moduledoc "Returns nil from match/1."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: nil
  end

  defmodule BadMarker do
    @moduledoc "Returns a plain map from marker/1."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def marker(_marker), do: %{tag: "section"}
  end

  defmodule BadContent do
    @moduledoc "Returns a single node instead of a list from content/2."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def content(_marker, _nodes), do: %MDEx.Paragraph{}
  end

  defmodule BadAddPosition do
    @moduledoc "Uses a position add/1 does not know."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(_marker), do: [middle: "x"]
  end

  defmodule BadAddValue do
    @moduledoc "Returns an integer as content from add/1."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(_marker), do: [start: 42]
  end

  defmodule BadWrap do
    @moduledoc "Returns a string where wrap/1 expects a Marker."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def wrap(_marker), do: [inner: "div"]
  end

  defmodule BadWrapPosition do
    @moduledoc "Uses a position wrap/1 does not know."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def wrap(_marker), do: [around: %Marker{tag: "div"}]
  end

  describe "malformed return values" do
    test "match/1 returning a non-boolean raises" do
      assert_raise ArgumentError, ~r/BadMatch\.match\/1 must return a boolean, got: nil/, fn ->
        render([BadMatch])
      end
    end

    test "marker/1 returning something other than a Marker raises" do
      assert_raise ArgumentError, ~r/BadMarker\.marker\/1 must return/, fn ->
        render([BadMarker])
      end
    end

    test "content/2 returning a non-list raises" do
      assert_raise ArgumentError, ~r/BadContent\.content\/2 must return a list of nodes/, fn ->
        render([BadContent])
      end
    end

    test "add/1 with an unknown position raises" do
      assert_raise ArgumentError, ~r/BadAddPosition\.add\/1 must return/, fn ->
        render([BadAddPosition])
      end
    end

    test "add/1 with a value that is neither a string nor a node raises" do
      assert_raise ArgumentError, ~r/BadAddValue\.add\/1 must return/, fn ->
        render([BadAddValue])
      end
    end

    test "wrap/1 with a value that is not a Marker raises" do
      assert_raise ArgumentError, ~r/BadWrap\.wrap\/1 must return/, fn ->
        render([BadWrap])
      end
    end

    test "wrap/1 with an unknown position raises" do
      assert_raise ArgumentError, ~r/BadWrapPosition\.wrap\/1 must return/, fn ->
        render([BadWrapPosition])
      end
    end
  end

  describe "several handlers" do
    test "a later handler wraps everything built so far, on both sides of the tag" do
      assert literals(render([LayerA, LayerB])) == [
               "B.before",
               "<b-outer>",
               "A.before",
               "<a-outer>",
               "<section>",
               "<b-inner>",
               "B.start",
               "<a-inner>",
               "A.start",
               "content",
               "A.end",
               "</a-inner>",
               "B.end",
               "</b-inner>",
               "</section>",
               "</a-outer>",
               "A.after",
               "</b-outer>",
               "B.after"
             ]
    end
  end
end
