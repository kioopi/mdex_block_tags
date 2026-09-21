defmodule MDExBlockTags.HandlerTest do
  use ExUnit.Case, async: true

  alias MDExBlockTags.Marker

  defmodule OnlyMatch do
    @moduledoc "A handler that implements nothing but the required callback."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true
  end

  defmodule Escaping do
    @moduledoc "A handler that overrides add/1 using the imported escape/1."
    use MDExBlockTags.Handler

    @impl true
    def match(_marker), do: true

    @impl true
    def add(%Marker{tag: tag}), do: [before: escape("<#{tag}>")]
  end

  @marker %Marker{tag: "section", classes: ["intro"]}

  describe "use MDExBlockTags.Handler" do
    test "declares the behaviour" do
      behaviours = OnlyMatch.module_info(:attributes) |> Keyword.get_values(:behaviour)

      assert [MDExBlockTags.Handler] in behaviours
    end

    test "marker/1 defaults to the marker unchanged" do
      assert OnlyMatch.marker(@marker) == @marker
    end

    test "add/1 defaults to no content" do
      assert OnlyMatch.add(@marker) == []
    end

    test "wrap/1 defaults to no wrappers" do
      assert OnlyMatch.wrap(@marker) == []
    end

    test "content/2 defaults to the children unchanged" do
      nodes = [%MDEx.Paragraph{nodes: [%MDEx.Text{literal: "Hi"}]}]

      assert OnlyMatch.content(@marker, nodes) == nodes
    end

    test "imports escape/1 and aliases Marker, and a default can be overridden" do
      assert Escaping.add(@marker) == [before: "&lt;section&gt;"]
    end
  end
end
