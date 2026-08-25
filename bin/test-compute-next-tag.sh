#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Gotenberg 8.36.0 which has already seen
# two releases of it (v8.36.0-0 and v8.36.0-1), plus `v8-0` and `v8-1` tags of
# the shape the commit-message era could produce out of Renovate's "Docker tag
# to v8" subjects. Those must not be counted as releases of anything.
#
# The defaults file deliberately carries the traps this role's real one has: the
# Renovate annotation that sits directly above the version, and the image tag and
# image name derived from it. None of them may be picked up as the version.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# renovate: datasource=docker depName=gotenberg/gotenberg versioning=semver
		gotenberg_version: 8.36.0

		gotenberg_container_image: "{{ gotenberg_container_image_registry_prefix }}gotenberg/gotenberg:{{ gotenberg_container_image_tag }}"
		gotenberg_container_image_tag: "{{ gotenberg_version }}"
	YAML
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v8-0 v8-1 v8.36.0-0 v8.36.0-1; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^gotenberg_version: 8.36.0|gotenberg_version: 8.37.0|' defaults/main.yml"
revert_version="sed -i 's|^gotenberg_version: 8.37.0|gotenberg_version: 8.36.0|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v8.37.0-0 "$(merge "$bump_version")"
expect 'task edit'    v8.37.0-1 "$(merge "$edit_task")"
expect 'template'     v8.37.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v8.36.0-2 "$(merge "$edit_task")"
expect 'version bump' v8.37.0-0 "$(merge "$bump_version")"

# `v8-0` and `v8-1` exist in every scenario. If the version were ever read as a
# bare major - which is exactly the mistake the commit-message era could make -
# the counter would continue from those instead of starting afresh.
scenario 'The floating-major tags of the commit-message era'
expect 'a task' v8.36.0-2 "$(merge "$edit_task")"

scenario 'Commits that do not affect the role'
expect 'README'   ''         "$(merge "$edit_readme")"
expect 'a script' ''         "$(merge "$edit_script")"
expect 'a task'   v8.36.0-2  "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v8.36.0-$release_number"
done
expect 'a task' v8.36.0-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v8.36.0-1 already published, so there is
# nothing new to release.
expect 'a revert' ''         "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v8.36.0-2 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
