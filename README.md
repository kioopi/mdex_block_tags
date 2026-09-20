# MDExBlockTags

An [MDEx](https://hexdocs.pm/mdex) plugin that wraps Markdown content in
semantic HTML block elements, using HTML comments as markers. The markers are
inert in every other Markdown renderer.

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
  <p>Content</p>
</section>

<nav class="main blue" id="12" data-open="false">
  <p>Navigation content</p>
</nav>
```

## Installation

```elixir
def deps do
  [
    {:mdex_block_tags, "~> 0.1"}
  ]
end
```

## Usage

```elixir
MDEx.to_html!(markdown, plugins: [MDExBlockTags])

MDEx.new(plugins: [{MDExBlockTags, block_tags_allowed_tags: ~w(section aside)}])

MDEx.new() |> MDExBlockTags.attach()
```

## Options

| Option | Default |
|---|---|
| `:block_tags_allowed_tags` | `~w(section nav article aside main header footer div)` |
| `:block_tags_allowed_attributes` | `~w(id role title)` |

Attribute names beginning with `data-` or `aria-` are always permitted.

## Semantics

- A marker is a **complete, standalone** HTML comment: `<!-- @section intro -->`.
  `text <!-- @section -->` is not a marker, and `<!-- TODO: … -->` is left alone.
- Bare tokens become CSS classes. `key=value` tokens become attributes, split on
  the **first** `=` only. Values may be quoted: `title="Main navigation"`.
- Opening a block **implicitly closes** the previous one, so consecutive
  sections need no `<!-- @end -->`.
- A block still open at the **end of the document** is closed there.
- An `<!-- @end -->` with no open block is left in the document untouched.
- A marker naming a **disallowed attribute fails closed**: the entire marker is
  left as an ordinary comment rather than rendered with the attribute stripped.

## Safety

The wrappers this plugin emits are `MDEx.HtmlBlock` nodes, and MDEx renders
those only when the `:unsafe` render option is set. `attach/2` sets
`unsafe: true` for you — **which also means any other raw HTML in your Markdown
will render.**

Sanitization stays your decision. MDEx disables it by default and this plugin
will not enable it behind your back. If you have enabled it, `attach/2` extends
the allowlist so this plugin's own output survives:

```elixir
MDEx.to_html!(markdown,
  plugins: [MDExBlockTags],
  sanitize: MDEx.Document.default_sanitize_options()
)
```

For untrusted Markdown, enabling `:sanitize` is the recommended posture.

## Limitations

Blocks are flat. Opening a block closes the previous one, so a `<nav>` cannot be
nested inside a `<section>`. The rewriter is built around a depth-capped stack,
so nesting is a planned change rather than a rewrite.

## Contributing

- **Version control is [jj](https://jj-vcs.github.io/jj/)**, colocated with git.
  Use `jj describe` / `jj new` rather than `git commit`. There is no staging
  area — the working copy is itself a commit.
- **Commits follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)**:
  `<type>[(<scope>)][!]: <description>`, imperative present tense, lowercase, no
  trailing period. Types: `feat`, `fix`, `refactor`, `perf`, `style`, `test`,
  `docs`, `build`, `ops`, `chore`.
- **`CHANGELOG.md` is generated** from those commits with
  [git-cliff](https://git-cliff.org/) and is never hand-edited.
- **Everything needs a test**, written first — red, green, refactor.
- Run `mix format`, `mix compile --warnings-as-errors` and `mix test` before
  committing.

## Licence

MIT © Tsoumenis Vangelis
