defmodule MDExBlockTags.HandlersTest do
  use ExUnit.Case, async: true

  alias MDExBlockTags.Handlers
  alias MDExBlockTags.Marker

  doctest MDExBlockTags.Handlers

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
  end
end
