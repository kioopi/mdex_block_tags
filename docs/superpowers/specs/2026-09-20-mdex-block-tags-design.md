# MDExBlockTags — Design

**Date:** 2026-09-20
**Status:** Approved, ready for implementation planning

## 1. Goal

Extract the `TableauTest.Markdown.BlockTags` MDEx plugin from the `tableau_test`
playground into a standalone, documented, tested Hex-ready library at
`~/projects/mdex_block_tags`.

The plugin lets Markdown authors wrap block-level content in semantic HTML
elements using HTML comments, which are inert in every other Markdown renderer:

```markdown
<!-- @section introduction -->

Content

<!-- @nav main blue id=12 data-open=false -->

Navigation content

<!-- @end -->
```

renders as:

```html
<section class="introduction">
  ...
</section>

<nav class="main blue" id="12" data-open="false">
  ...
</nav>
```

## 2. Origin and scope

The source is `tableau_test/lib/markdown/block_tags.ex` (~290 lines, one module).
Its behavior is the specification: **the extracted library must produce
byte-identical output for the same input**, with two deliberate exceptions
recorded in §8 (safety) and §5 (option names).

### Non-goals for v1

- **Nesting.** Blocks stay flat, exactly as today. The rewriter is *structured*
  so nesting is a configuration change rather than a rewrite (§7), but the
  capability is not exposed.
- **Configurable attribute prefixes.** `data-` and `aria-` stay hardcoded. A
  `:block_tags_attribute_prefixes` option is a trivial later addition.
- **Configurable marker syntax.** The `@` sigil and HTML-comment form are fixed.
- **Inline (non-block) markers.** Only `MDEx.HtmlBlock` nodes are considered.
- **Replacing MDEx's `block_directive` (`:::`) extension.** This is a
  complementary, deliberately different mechanism.

## 3. Naming

- Hex package: `mdex_block_tags`
- Root module: `MDExBlockTags` (no dot)
- Option prefix: `:block_tags_`

Rationale: the `MDEx.` namespace belongs to the `mdex` package, which defines
`MDEx.Document`, `MDEx.HtmlBlock` and friends. A third-party package publishing
into that namespace risks collision and muddies module-name completion. MDEx's
own plugin guide names its worked example `MDExMermaid` and prefixes its options
(`:mermaid_version`) for the same reason. This is an MDEx convention, not an
Elixir language rule — the Elixir library guidelines page has no namespace
section.

## 4. Repository layout

```
mdex_block_tags/
├── mise.toml
├── mix.exs
├── mix.lock                        # committed
├── .formatter.exs
├── .gitignore
├── README.md
├── CHANGELOG.md
├── LICENSE                         # MIT
├── .github/workflows/ci.yml
├── docs/superpowers/specs/         # this document
├── lib/
│   ├── mdex_block_tags.ex          # MDExBlockTags
│   └── mdex_block_tags/
│       ├── marker.ex               # MDExBlockTags.Marker
│       ├── rewriter.ex             # MDExBlockTags.Rewriter
│       └── html.ex                 # MDExBlockTags.HTML
└── test/
    ├── test_helper.exs
    ├── mdex_block_tags_test.exs
    └── mdex_block_tags/
        ├── marker_test.exs
        ├── rewriter_test.exs
        └── html_test.exs
```

### mise.toml

Pinned to the toolchain currently in use (Elixir 1.20.2 / Erlang OTP 29):

```toml
[tools]
erlang = "29"
elixir = "1.20-otp-29"
```

### mix.exs

```elixir
defmodule MDExBlockTags.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/OWNER/mdex_block_tags"

  def project do
    [
      app: :mdex_block_tags,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "MDExBlockTags",
      source_url: @source_url,
      description:
        "An MDEx plugin that wraps Markdown content in semantic HTML block " <>
          "elements using HTML comment markers."
    ]
  end

  def application, do: []

  defp deps do
    [
      {:mdex, "~> 0.13"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end

  defp docs do
    [main: "readme", extras: ["README.md", "CHANGELOG.md"], source_ref: "v#{@version}"]
  end
end
```

Notes:
- `elixir: "~> 1.15"` matches MDEx's own floor (`deps/mdex/mix.exs:11`).
- `def application, do: []` — no supervision tree, no runtime deps of its own,
  and the library never logs, so `extra_applications: [:logger]` is dropped.
- **`{:mdex, "~> 0.13"}` is a deliberate deviation** from the Elixir library
  guidelines, which recommend pinning pre-1.0 dependencies to the patch version
  (`~> 0.13.5`). The plugin only touches MDEx's documented plugin surface
  (`register_options/2`, `put_options/2`, `append_steps/2`,
  `put_render_options/2`, `put_sanitize_options/2`, `get_option/3`), so pinning
  to a patch would block users on every MDEx release for no benefit.
- `@source_url` **needs the real GitHub owner filled in before publishing.**

## 5. Public API

```elixir
# Attach with defaults
MDEx.to_html!(markdown, plugins: [MDExBlockTags])
MDEx.new(markdown: markdown, plugins: [MDExBlockTags])

# Attach with options
MDEx.new(plugins: [{MDExBlockTags, block_tags_allowed_tags: ~w(section aside)}])

# Attach manually
MDEx.new() |> MDExBlockTags.attach(block_tags_allowed_attributes: ~w(id lang))
```

`attach(document, options \\ [])` is the only public function on `MDExBlockTags`.

### Options

| Option | Type | Default |
|---|---|---|
| `:block_tags_allowed_tags` | `[String.t()]` | `~w(section nav article aside main header footer div)` |
| `:block_tags_allowed_attributes` | `[String.t()]` | `~w(id role title)` |

Attributes whose names begin with `data-` or `aria-` are always permitted, in
addition to `:block_tags_allowed_attributes`.

These replace the source module's single `:block_tags` option (which controlled
tags only). Attribute allowlisting was hardcoded and is now configurable.

The library reads **no application configuration**. All configuration flows
through `attach/2`.

## 6. Module responsibilities

Three of the four modules never reference MDEx, so they unit-test as pure
functions.

### `MDExBlockTags`

`attach/2` only, plus option reading and the safety steps. Registers options,
then appends three steps — rather than mutating the document inline as the
source module does. This matters: as steps, the render and sanitize decisions
run at *render* time, so they observe a `:sanitize` value the user set after
attaching the plugin.

```elixir
def attach(document, options \\ []) do
  document
  |> MDEx.Document.register_options([
       :block_tags_allowed_tags,
       :block_tags_allowed_attributes
     ])
  |> MDEx.Document.put_options(options)
  |> MDEx.Document.append_steps(block_tags_enable_unsafe: &enable_unsafe/1)
  |> MDEx.Document.append_steps(block_tags_extend_sanitize: &extend_sanitize/1)
  |> MDEx.Document.append_steps(block_tags_rewrite: &rewrite/1)
end
```

It also builds the config map passed down to the pure modules:

```elixir
%{allowed_tags: [String.t()], allowed_attributes: [String.t()]}
```

### `MDExBlockTags.Marker`

```elixir
defstruct [:tag, :classes, :attributes]

@type t :: %__MODULE__{
        tag: String.t(),
        classes: [String.t()],
        attributes: [{String.t(), String.t()}]
      }

@spec parse(String.t(), config) :: {:open, t()} | :close | :ordinary
```

Takes a **binary**, not a node, keeping the module free of MDEx. Owns the
regex, tokenizing, class-versus-attribute splitting, and the attribute
allowlist.

### `MDExBlockTags.Rewriter`

```elixir
@spec run([MDEx.Document.md_node()], config) :: [MDEx.Document.md_node()]
```

The fold over the node list and all implicit-close policy. It pattern-matches
`%MDEx.HtmlBlock{literal: literal}` and delegates to `Marker.parse/2`; every
other node type is `:ordinary` by construction.

### `MDExBlockTags.HTML`

```elixir
@spec open_tag(Marker.t()) :: String.t()
@spec close_tag(Marker.t()) :: String.t()
@spec escape_attribute(String.t()) :: String.t()
```

## 7. Behavior specification

### 7.1 Marker grammar

A node is a marker candidate only if it is an `MDEx.HtmlBlock` whose literal is
a **complete, standalone** HTML comment matching:

```elixir
~r/\A\s*<!--\s*@([a-z][a-z0-9-]*)(.*?)-->\s*\z/is
```

- `i` — `<!-- @SECTION -->` matches; the captured command is downcased.
- `s` — the comment may span multiple lines.
- Anchored — `text <!-- @section -->` is not a marker.

The captured command and the remaining token string then classify as:

| Command | Tokens | Result |
|---|---|---|
| `end` | none | `:close` |
| `end` | any | `:ordinary` |
| in `allowed_tags` | parse successfully | `{:open, %Marker{}}` |
| in `allowed_tags` | parse fails | `:ordinary` |
| not in `allowed_tags` | any | `:ordinary` |

Anything that is not a matching comment is `:ordinary`.

### 7.2 Token parsing

The text between the command and `-->` is trimmed and split with
`OptionParser.split/1`, giving shell-like quoting:

```
title=Introduction
title="Main navigation"
```

Each token is then:

- **No `=`** → a CSS class.
- **`key=value`** (split on the first `=` only, `parts: 2`) → an HTML attribute,
  if `key` is in `allowed_attributes` or begins with `data-` or `aria-`.

If **any** token names a disallowed attribute, the **entire marker** degrades to
`:ordinary` and the comment is left in the document untouched. This fail-closed
behavior is intentional and inherited from the source module; it is surprising
enough to warrant an explicit test and a README note.

Class and attribute order is preserved.

### 7.3 Rewriter state machine

The source module's `open :: nil | block` becomes `stack :: [block]`, with flat
behavior expressed as a depth cap:

```elixir
@max_depth 1   # v1 is flat. :infinity enables nesting.
```

A block is `%{marker: Marker.t(), nodes: [node], sourcepos: sourcepos}`.

| Input | `stack == []` | `depth == @max_depth` | otherwise |
|---|---|---|---|
| `{:open, m}` | push | close top, then push | push |
| `:close` | emit the comment node unchanged (orphan `@end`) | close top | close top |
| `:ordinary` | emit to output | accumulate into `hd(stack)` | accumulate into `hd(stack)` |
| end of nodes | — | close all | close all |

At `@max_depth 1` this is byte-identical to the source module.

### 7.4 Closing a block

Both `output` and each block's `nodes` accumulate in reverse; the whole result
is reversed once at the end.

```elixir
defp close_top([block | rest], output) do
  opening = %MDEx.HtmlBlock{
    literal: HTML.open_tag(block.marker) <> "\n",
    sourcepos: block.sourcepos
  }

  closing = %MDEx.HtmlBlock{literal: HTML.close_tag(block.marker) <> "\n"}

  # reverse order: </tag>, children…, <tag>
  wrapped = [closing | block.nodes] ++ [opening]

  case rest do
    [] -> {rest, wrapped ++ output}
    [parent | tail] -> {[%{parent | nodes: wrapped ++ parent.nodes} | tail], output}
  end
end
```

The `rest`/`parent` split is the single change that makes nesting a
configuration change instead of a rewrite. With `@max_depth 1` the `parent`
branch is unreachable, but the shape is correct for the day the cap lifts.

`sourcepos` from the marker node is carried onto the synthetic opening node; the
closing node has none.

### 7.5 HTML serialization

```
<tag class="a b" id="12" data-open="false">
```

- No classes → no `class` attribute at all (not `class=""`).
- Classes joined with a single space.
- Attributes emitted in source order, after `class`.
- Attribute **values** (including the joined class string) are escaped:
  `&` → `&amp;`, `"` → `&quot;`, `<` → `&lt;`, `>` → `&gt;`.
  `&` is replaced first so the other replacements are not double-escaped.
- Attribute **names** need no escaping — they already passed the allowlist.

## 8. Safety policy

`unsafe: true` is unavoidable: MDEx gates `HtmlBlock` rendering on it, and the
wrappers this plugin emits *are* `HtmlBlock` nodes. There is no per-node bypass.
So `attach/2` always sets it, and the README says so prominently.

Sanitization is the deliberate change from the source module. In MDEx,
`:sanitize` defaults to `nil` — disabled (`deps/mdex/lib/mdex/document.ex:1307`)
— and `put_sanitize_options/2` merges onto `sanitize || []`. The source module
calls it unconditionally, which means **attaching the plugin silently switches
ammonia sanitization on** for every user, including those who deliberately had
it off.

A library must not make that decision for its host. The rule is:

```elixir
defp extend_sanitize(document) do
  case MDEx.Document.get_option(document, :sanitize) do
    nil ->
      document

    _enabled ->
      MDEx.Document.put_sanitize_options(document,
        add_tags: allowed_tags(document),
        add_generic_attributes: ["id", "class", "role"],
        add_generic_attribute_prefixes: ["data-", "aria-"]
      )
  end
end
```

- Sanitization off → left off. The user's choice stands.
- Sanitization on → the allowlist is extended so the plugin's own output
  survives the scrubber, while everything else the user configured is untouched.

The README must document that sanitization is the user's responsibility, that
`unsafe: true` is set on their behalf and what that implies, and that enabling
`:sanitize` is the recommended posture for untrusted Markdown.

## 9. Testing strategy

Roughly 48 tests across four files, plus doctests on `MDExBlockTags.attach/2`.

### `test/mdex_block_tags/marker_test.exs` (21)

The bulk of the suite — the grammar is where the bugs live.

1. `<!-- @section intro -->` → `{:open, %Marker{tag: "section", classes: ["intro"]}}`
2. `<!-- @end -->` → `:close`
3. `<!-- @end extra -->` → `:ordinary`
4. `<!-- TODO: rewrite this -->` → `:ordinary`
5. `<!-- @script -->` (tag not in allowlist) → `:ordinary`
6. `<!-- @SECTION intro -->` → matches, tag downcased to `"section"`
7. Multi-line comment → matches
8. Leading/trailing whitespace around the comment → matches
9. `text <!-- @section -->` (not standalone) → `:ordinary`
10. Bare marker `<!-- @section -->` → no classes, no attributes
11. Multiple classes → order preserved
12. `id=12` → `{"id", "12"}`
13. `title="Main navigation"` → quoted value preserved with its space
14. `data-open=false` → allowed
15. `aria-label=Menu` → allowed
16. `onclick=alert(1)` → **whole marker** becomes `:ordinary`
17. `data-x=a=b` → `{"data-x", "a=b"}` (splits on the first `=` only)
18. `id=` → `{"id", ""}`
19. Mixed classes and attributes → both lists in source order
20. Custom `allowed_tags` config → previously valid default tag now `:ordinary`
21. Custom `allowed_attributes` config → previously rejected name now accepted

### `test/mdex_block_tags/html_test.exs` (6)

1. No classes → no `class` attribute in the output
2. Multiple classes → joined with a single space
3. Attributes rendered in order after `class`
4. `&`, `"`, `<`, `>` each escaped in a value
5. `&` escaped exactly once (no double-escaping of `&amp;`)
6. `close_tag/1` → `</section>`

### `test/mdex_block_tags/rewriter_test.exs` (12)

Hand-built node lists, no rendering.

1. Single marker + content → wrapped
2. A new opener implicitly closes the previous block
3. Explicit `<!-- @end -->` closes
4. End of nodes implicitly closes an open block
5. Orphan `<!-- @end -->` (no open block) survives as an ordinary node
6. Marker with no following content → empty wrapper
7. Content before the first marker is emitted untouched
8. Content after an `@end` is emitted untouched
9. **Node order preserved** across several children — guards the double-reverse
   documented at `block_tags.ex:243`
10. `sourcepos` from the marker lands on the synthetic opening node
11. Non-`HtmlBlock` nodes are never treated as markers
12. An `HtmlBlock` that is not a comment (e.g. `<div>raw</div>`) is `:ordinary`

### `test/mdex_block_tags_test.exs` (9)

End-to-end through `MDEx.to_html!/2`.

1. Default attach produces `<section class="introduction">…</section>`
2. `:block_tags_allowed_tags` override takes effect
3. `:block_tags_allowed_attributes` override takes effect
4. `unsafe` is enabled (raw HTML in the source renders)
5. **`:sanitize` left `nil` stays `nil`** — regression test for §8
6. `:sanitize` already enabled → plugin tags survive the scrubber
7. `:sanitize` already enabled → `<script>` in the *source* is still stripped
8. Composes with a second plugin without interference
9. `{MDExBlockTags, opts}` tuple form works as well as the bare module

StreamData is not used in v1; the grammar is small enough for example-based
tests.

## 10. Documentation

**README.md** — what it does (before/after Markdown and HTML), installation,
usage, the options table, a **Safety** section (§8), a **Semantics** section
(implicit close on a new opener, close at end of document, orphan `@end`,
fail-closed attributes), and **Limitations** (no nesting in v1).

**Module docs** — `MDExBlockTags` carries the user-facing `@moduledoc` adapted
from the source module. `Marker`, `Rewriter` and `HTML` get brief `@moduledoc`s;
they are public-by-necessity, not public API.

**CHANGELOG.md** — Keep a Changelog format, starting at `0.1.0`.

## 11. CI

`.github/workflows/ci.yml`, two jobs:

- **test** — checkout, `setup-beam` on a small Elixir/OTP matrix, restore deps
  cache, `mix deps.get`, `mix format --check-formatted`,
  `mix compile --warnings-as-errors`, `mix test`.
- **test-latest-deps** — as above but `mix deps.unlock --all` first, so the
  library is validated against the newest dependency versions its requirements
  permit. Per the Elixir library guidelines; runs on a schedule and on
  `workflow_dispatch`, and is not required for merge.

## 12. Migration of `tableau_test`

After the library is green, in `~/projects/cms_research/tableau_test`:

1. Add `{:mdex_block_tags, path: "../../mdex_block_tags"}` to `deps/0`.
2. Delete `lib/markdown/block_tags.ex`.
3. Change `config/config.exs:33` from `TableauTest.Markdown.BlockTags` to
   `MDExBlockTags`.
4. Rebuild and compare output.

**Expected difference:** the site currently gets ammonia sanitization switched
on as a side effect of attaching the plugin (§8). Once the library respects the
host document, sanitization will be off and the rendered HTML may differ. If the
scrubbing is wanted, add explicit `sanitize:` options to the site's `mdex`
config. This is a decision for that repo, not this one.

## 13. Deferred

Recorded so they are choices, not oversights:

- Nesting (`@max_depth :infinity`, behind an option).
- `:block_tags_attribute_prefixes` for e.g. `hx-`.
- Property-based tests for tag balance.
- Publishing to Hex — requires the real `@source_url` owner first.
