# Security policy

## Reporting a vulnerability

Please **do not open a public issue**. Use GitHub's private reporting instead:
[Report a vulnerability](https://github.com/zxxdev/roadmap-badges/security/advisories/new).

Include the file or input involved, what an attacker could do, and the steps to reproduce it.
I will acknowledge the report within a week and keep you updated until it is fixed.

## Scope

This is a GitHub Action: it runs inside other people's workflows, with their token and their files.
The main risks are:

- a compromised build dependency that ends up inside the bundled `dist/index.js`;
- input from a repository (catalog, test reports, names) that breaks the generated badges or
  reports, for example text that injects markup into an SVG or HTML file;
- the action asking for more permissions than it needs.

Reports about any of these are welcome.

## Supported versions

The action is not released yet. Once it is, only the latest version of the current major tag
(for example `v1`) will receive fixes.
