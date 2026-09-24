## [0.2.0] - 2026-09-24

### Features

- *(handler)* Add the MDExBlockTags.Handler behaviour
- *(handler)* Adds handlers to customize block HTML
- Add :block_tags_classifier and :block_tags_renderer options

### Bug Fixes

- *(marker)* Reject invalid attribute-name characters and stop a crash on unbalanced quotes
- Scope sanitizer attribute allowlist extension to the plugin's own tags

### Refactor

- *(html)* Rename escape_attribute/1 to escape/1
- *(rewriter)* Render closed blocks through MDExBlockTags.Handlers

### Documentation

- Document sanitizer scoping residual, top-level-only markers, and fix stale gitignore pattern
- Document the development workflow and the release process

### Testing

- Cover the security fixes, sanitizer scoping, and top-level-only markers end-to-end
- Add current Elixir version to test matrix

### Build

- Add credo, dialyxir, ex_dna, ex_slop and reach
- *(mise)* Fetch mix dependencies after mise install

### Operations

- Add github actions workflow
- *(ci)* Run quality checks in CI and cache dialyzer PLTs
- *(release)* Add a mise task that cuts a release

## [0.1.0] - 2026-09-20

### Features

- *(marker)* Recognise block marker comments
- *(marker)* Parse classes and attributes from markers
- *(html)* Serialise markers into opening and closing tags
- *(rewriter)* Wrap marked regions in html block tags
- Add MDExBlockTags plugin entry point

### Bug Fixes

- Extend sanitize allowlist with configured attributes, not a static list

### Documentation

- Add readme, changelog and git-cliff config

