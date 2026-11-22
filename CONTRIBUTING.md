# Contributing

Bug reports and suggestions are very welcome: please
[open an issue](https://github.com/zxxdev/roadmap-badges/issues/new/choose).
For security problems, follow [SECURITY.md](SECURITY.md) instead.

## How changes are made

Every change follows the same path, including my own:

1. An issue describes the change and its acceptance criteria.
2. Work happens on a branch named `<type>/<issue>-<summary>`, for example `feat/12-junit-reader`.
3. Commits follow [Conventional Commits](https://www.conventionalcommits.org/):
   `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `build`, `ci`, `chore`.
4. A pull request closes the issue. CI must be green before it is merged.
5. Pull requests are squash-merged, so `main` keeps one commit per change.

## Running the checks

Requirements: Node.js 24 or later and pnpm 12 (the exact version is in `package.json`).

```sh
pnpm install --frozen-lockfile
pnpm format:check  # Prettier
pnpm lint          # ESLint with type-aware rules
pnpm typecheck     # TypeScript
pnpm test          # Vitest
pnpm bundle        # Rollup: builds dist/index.js
pnpm all           # all of the above, in that order
```

## The bundle in `dist/`

GitHub runs `dist/index.js` exactly as it is in the repository and installs nothing, so the
bundle is committed. **If you change `src/`, run `pnpm bundle` and commit `dist/` in the same
pull request.** CI rebuilds it and fails if it differs from what is committed.

## Adding a dependency

Fewer dependencies is better: every runtime dependency ends up inside `dist/index.js` and runs in
other people's workflows. If a new package is really needed, the pull request must say:

- that it is the official package (linked repository, maintainers, documentation that recommends it);
- that the version is at least 7 days old (pnpm enforces this, see `pnpm-workspace.yaml`);
- whether it needs an install script, and why. Install scripts are blocked unless listed in
  `allowBuilds`.
