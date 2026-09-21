defmodule MDExBlockTags.Handler do
  @moduledoc """
  A behaviour for customising the HTML emitted for particular blocks.

  A handler decides with `c:match/1` whether it applies to a block, and can
  then change the block's marker, add content around or inside it, wrap it in
  further elements, or rewrite its children. Register handlers with the
  `:block_tags_handlers` option; they apply in list order, and each one sees
  the result of the ones before it.

      defmodule MyApp.DocsSection do
        use MDExBlockTags.Handler

        @impl true
        def match(%Marker{tag: "section", classes: classes}), do: "docs" in classes
        def match(_marker), do: false

        @impl true
        def add(_marker), do: [before: ~s(<a href="/docs">Back to Documentation</a>)]

        @impl true
        def wrap(_marker), do: [inner: %Marker{tag: "div", classes: ["doc-container"]}]
      end

  `c:match/1` is called for **every** block, so it needs a catch-all clause.

  ## Positions

  For one handler, the rendered block is laid out as:

      before · <outer> · <tag> · <inner> · start · children · end · </inner> · </tag> · </outer> · after

  Each further handler wraps everything built so far, on both sides of the
  tag, so a later handler always sits further from the children. Repeated
  positions in one return value follow the same rule: the first wrapper sits
  closest to the children, and `[start: a, start: b]` renders `a` then `b`.

  ## `use MDExBlockTags.Handler`

  Declares the behaviour, aliases `MDExBlockTags.Marker` as `Marker`, imports
  `MDExBlockTags.HTML.escape/1`, and defines overridable defaults for every
  callback except `c:match/1`.

  ## Trust

  Handler output is not checked against `:block_tags_allowed_tags` or
  `:block_tags_allowed_attributes`: handlers are code, not Markdown. Strings
  are inserted as raw HTML, so escape marker values with `escape/1` before
  interpolating them. A malformed return value raises `ArgumentError`.
  """

  alias MDExBlockTags.Marker

  @typedoc "Content to insert: raw HTML as a string, or an MDEx node."
  @type content :: String.t() | MDEx.Document.md_node()

  @typedoc "Where `c:add/1` places content."
  @type add_position :: :before | :start | :end | :after

  @typedoc "Where `c:wrap/1` places a wrapper."
  @type wrap_position :: :inner | :outer

  @doc "Returns whether this handler applies to the block opened by `marker`."
  @callback match(marker :: Marker.t()) :: boolean()

  @doc "Returns the marker to render the block with. Defaults to `marker`."
  @callback marker(marker :: Marker.t()) :: Marker.t()

  @doc """
  Returns content to insert, keyed by position. A bare value means `:start`.
  Defaults to `[]`.
  """
  @callback add(marker :: Marker.t()) :: content() | [{add_position(), content()}]

  @doc """
  Returns markers to render as wrapper elements, keyed by position. A bare
  marker means `:outer`. Defaults to `[]`.
  """
  @callback wrap(marker :: Marker.t()) :: Marker.t() | [{wrap_position(), Marker.t()}]

  @doc """
  Returns the block's children, in document order. Defaults to `nodes`.
  Runs before this handler's `:start`, `:end` and `:inner` additions.
  """
  @callback content(marker :: Marker.t(), nodes :: [MDEx.Document.md_node()]) ::
              [MDEx.Document.md_node()]

  defmacro __using__(_options) do
    quote do
      @behaviour MDExBlockTags.Handler

      alias MDExBlockTags.Marker
      import MDExBlockTags.HTML, only: [escape: 1]

      @impl MDExBlockTags.Handler
      def marker(marker), do: marker

      @impl MDExBlockTags.Handler
      def add(_marker), do: []

      @impl MDExBlockTags.Handler
      def wrap(_marker), do: []

      @impl MDExBlockTags.Handler
      def content(_marker, nodes), do: nodes

      defoverridable marker: 1, add: 1, wrap: 1, content: 2
    end
  end
end
