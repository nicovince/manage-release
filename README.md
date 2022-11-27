# manage-release

This action is inspried from [johnwbyrd/update-release](https://github.com/johnwbyrd/update-release) and tries to be compatible with it.

Since the original action was written using `node12` for which github dropped supports I decided to write my own action to manage release using a composite action based on bash shell scripts and [`gh`](https://cli.github.com/).

:warning: Development is still in progress.

## Setup action
In your desired workflow (`.github/workflows/`), insert the following lines:

Rolling release:
```yaml
on:
  push:
    branches: [ '*' ]
jobs:
  rolling_release:
    runs-on: ubuntu-latest
    name: Rolling Release on Branch
    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Release
        uses: nicovince/manage-release@main
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          files: <list of files>
          sha1: ${{ github.sha }}
```

