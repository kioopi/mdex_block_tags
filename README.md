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

Not yet published on Hex — use a `path:` or `github:` dependency for now:

```elixir
def deps do
  [
    {:mdex_block_tags, github: "kioopi/mdex_block_tags"}
  ]
end
```

Once published, it will be:

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

When sanitization is enabled, the allowlist extension is scoped to this
plugin's own tags: `:block_tags_allowed_attributes` (plus `class`) are only
permitted on `:block_tags_allowed_tags`, not on every element in the
document. One residual exception: `data-*` and `aria-*` attribute names are
always allowed, and [ammonia](https://github.com/rust-ammonia/ammonia) (the
sanitizer MDEx uses) has no per-tag prefix option, so
`add_generic_attribute_prefixes` necessarily widens those two prefixes to
every tag in the document — not just this plugin's.

## Limitations

Blocks are flat. Opening a block closes the previous one, so a `<nav>` cannot be
nested inside a `<section>`. 

Markers are recognised only at the **top level of the document**
The rewriter folds `document.nodes` and does not descend into container blocks.
A marker written inside a list item, a blockquote, or any other nested block
is not recognised as a marker; with `unsafe: true` (which `attach/2` always
sets) it survives into the output as a raw, inert HTML comment instead.

## Development

The toolchain (Erlang, Elixir and git-cliff) is pinned in `mise.toml`:

```sh
mise install
mix deps.get
```

Day to day:

```sh
mix test                          # the test suite, including doctests
mix test test/mdex_block_tags_test.exs:42   # a single test
mix format                        # format the code
mix docs                          # build the docs into doc/
```

Before calling a change done, run everything CI runs:

```sh
mix ci
```

`mix ci` runs in the `test` environment and chains
`compile --warnings-as-errors`, `format --check-formatted`, `test`,
`credo --strict` (with the [ExSlop](https://hex.pm/packages/ex_slop) plugin),
`dialyzer`, `ex_dna --max-clones 0` and `reach.check --arch --smells`. The
first run builds the Dialyzer PLTs into `priv/plts/` (gitignored), which takes
a minute or two. Later runs reuse them.

The repository uses [Jujutsu](https://jj-vcs.github.io/jj/), colocated with
git. Use `jj` for anything that changes history. Read-only `git` commands such
as `git log` and `git diff` are fine, but `git commit`, `git rebase`,
`git checkout` and friends will confuse jj's view of the working copy.

## Contributing

- **Commits follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)**:
  `<type>[(<scope>)][!]: <description>`, imperative present tense, lowercase, no
  trailing period. Types: `feat`, `fix`, `refactor`, `perf`, `style`, `test`,
  `docs`, `build`, `ops`, `chore`.
- **`CHANGELOG.md` is generated** from those commits with
  [git-cliff](https://git-cliff.org/) and is never hand-edited. A badly worded
  entry is fixed by rewording the commit (`jj describe -r <change>`), not the
  changelog.
- **Everything needs a test**, written first — red, green, refactor.
- `mix ci` must pass before a change is pushed.

## Releasing

Versions follow [SemVer](https://semver.org/), derived from the commit types:
`fix` → patch, `feat` → minor, a breaking change → major. While the library is
below 1.0, breaking changes bump the minor version and are called out in the
changelog.

**How git-cliff and jj fit together.** In a colocated repository jj keeps git's
`HEAD` on the *parent* of the working-copy change (`@-`), not on `@` itself.
git-cliff reads git, so it only sees changes below `@`. The procedure below
relies on that: every change being released is committed below `@`, and the
release change (version bump and changelog) is `@`, which git-cliff does not
see.

1. **Start the release change on top of `main`.** Make sure `main` points at
   the last change to release and `mix ci` passes there.

   ```sh
   jj new main -m "chore(release): v0.2.0"
   ```

2. **Check that git sees the same history as jj.** jj normally exports to git
   on every command, but a stale ref makes git-cliff walk the wrong history
   *without an error*:

   ```sh
   jj git export
   git log --oneline -3 HEAD         # the top line must be main's latest change
   ```

3. **Bump `@version` in `mix.exs`.**

4. **Preview, then generate the changelog.** Run this from the repository
   root, **not** from a jj workspace under `.workspaces/`: a secondary
   workspace has no `.git`, and git-cliff there exits successfully with an
   empty changelog.

   ```sh
   git cliff --unreleased --tag v0.2.0    # preview the new section
   git cliff --tag v0.2.0 -o CHANGELOG.md
   ```

   **Read `CHANGELOG.md` before going on.** Both failure modes above produce a
   well-formed file that is wrong, not an error. Only conventional commits are
   listed, and `chore` commits are skipped (see `cliff.toml`), which is why the
   release change itself never shows up.

5. **Verify, then seal the release change and move `main` onto it.**

   ```sh
   mix ci
   jj new
   jj bookmark move main --to @-
   ```

6. **Tag and push.** jj creates and pushes the tag itself. `mix docs` links
   to the source at `v<version>`, so the tag must exist on GitHub.

   ```sh
   jj tag set v0.2.0 -r main
   jj git push --bookmark main --tag v0.2.0
   ```

7. **Publish to Hex.**

   ```sh
   mix hex.publish
   ```

## Licence

MIT © Vangelis Tsoumenis
