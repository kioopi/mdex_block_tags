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

The toolchain (Erlang, Elixir and git-cliff) is pinned in `mise.toml`.
`mise install` installs it and then runs `mix deps.get` through a
`postinstall` hook:

```sh
mise install
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

A release is cut from whatever `main` points at, by a mise task in
`scripts/release`. Check it first with a dry run, which changes nothing:

```sh
mise run release 0.2.0 --dry-run
```

It checks the history and prints the commits since the last release and the
changelog section they produce. **Read that section.** Only conventional
commits are listed. If an entry is wrong, reword its commit
(`jj describe -r <change>`) and run the dry run again.

Then release:

```sh
mise run release 0.2.0
```

This:

1. refuses to run if the version is not newer than `mix.exs`, its tag already
   exists, `main` is behind `origin`, a change to be released has no
   description, or git's refs disagree with jj;
2. creates a `chore(release): v0.2.0` change on top of `main` and bumps
   `@version` in `mix.exs`;
3. regenerates `CHANGELOG.md` with git-cliff;
4. runs `mix ci`;
5. moves `main` onto the release change and tags it `v0.2.0`;
6. pushes `main` and the tag with `jj git push`;
7. prints a summary and the steps for publishing to Hex:

   ```sh
   mix hex.user whoami     # otherwise: mix hex.user auth
   mix hex.build           # inspect the package contents
   mix hex.publish         # publish the package and its docs
   ```

If anything fails before the push, nothing has been pushed and the task
prints the `jj op restore <operation>` command that undoes every local change.

`mise run test:release` runs the release task against a throwaway copy of the
repository with a local bare repository as `origin`. Run it after changing
either script.

### How git-cliff and jj fit together

The task handles the following, but it matters if you ever release by hand.

- In a colocated repository jj keeps git's `HEAD` on the *parent* of the
  working-copy change (`@-`), not on `@` itself. git-cliff reads git, so it
  only sees changes below `@`. The release change (version bump and
  changelog) is `@` while the changelog is generated, so git-cliff never sees
  it. The `chore` type keeps it out of the changelog later as well (see
  `cliff.toml`).
- A stale git ref makes git-cliff walk the wrong history **without an
  error**. Run `jj git export` and compare `git log --oneline -1 main` with
  `jj log -r main` before generating.
- Run git-cliff from the repository root, never from a jj workspace under
  `.workspaces/`. A secondary workspace has no `.git`, and git-cliff there
  exits successfully with an empty changelog.

## Licence

MIT © Vangelis Tsoumenis
