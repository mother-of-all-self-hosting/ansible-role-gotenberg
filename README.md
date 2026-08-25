<!--
SPDX-FileCopyrightText: 2023, 2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2024 Julian-Samuel Gebühr
SPDX-FileCopyrightText: 2025, 2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Gotenberg Ansible role

This is an [Ansible](https://www.ansible.com/) role which installs [Gotenberg](https://gotenberg.dev/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

Check [`defaults/main.yml`](defaults/main.yml) for the full list of supported options. Refer to [this page](docs/configuring-gotenberg.md) for details about setting up the service with this role.

💡 For an Ansible playbook which integrates this role and makes it easier to use, see the [Mother-of-All-Self-Hosting Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

## Development

### pre-commit

You can optionally install a Git pre-commit hook (via [mise](https://mise.jdx.dev/) + [prek](https://prek.j178.dev/)) that runs formatting and linting checks before each commit. See [`.pre-commit-config.yaml`](./.pre-commit-config.yaml) for which hooks are to be executed.

To install the hook, run the [`just`](https://github.com/casey/just) command below:

```sh
just prek-install-git-pre-commit-hook
```

### Molecule

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

Refer to [this page](./molecule/README.md) for details about how to utilize it.

### Releases

Release tags (`v<Gotenberg version>-<release>`) are cut automatically by the [autotag workflow](./.github/workflows/autotag.yml), derived from the state of the repository rather than from commit messages. [`bin/compute-next-tag.sh`](./bin/compute-next-tag.sh) reads the Gotenberg version out of [`defaults/main.yml`](./defaults/main.yml) and compares it against the tags that already exist: a version that has never been released starts at `-0`, and any other change under `defaults/`, `meta/`, `tasks/` or `templates/` increments the counter. Changes that cannot affect a playbook run — documentation, CI configuration, the Molecule scenario — release nothing.

Because the result is derived from the repository rather than from the order in which pull requests were merged, pull requests are safe to merge in any order. [`bin/test-compute-next-tag.sh`](./bin/test-compute-next-tag.sh) exercises the computation against throwaway repositories, and runs as a pre-commit hook whenever the version or either script changes.
