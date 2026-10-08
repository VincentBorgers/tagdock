# Contributing

Bug reports and pull requests are welcome. For a larger change, open an issue first so we can agree on the approach before you spend time on it.

## Before you open a pull request

- Run ShellCheck and the tests. Both run in Docker, so you don't need to install anything else.

  ```sh
  docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -x tagdock tests/tagdock.bats
  docker run --rm -v "$PWD:/code" -w /code bats/bats:latest tests
  ```

- Add a test in `tests/tagdock.bats` for a bug fix or a new option.
- Keep the script dependency free. It should run with Bash 4, coreutils and Docker.
- Update the README and `CHANGELOG.md` when you change behaviour or add an option.

## Testing against a real tagging server

The tests do not start containers. To try a change end to end you need a server container config from Tag Manager. Use `PROXY=none` or a separate `COMPOSE_PROJECT` so a test run does not touch a server you already have running.
