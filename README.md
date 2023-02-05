# manage-release

This action is inspried from [johnwbyrd/update-release](https://github.com/johnwbyrd/update-release) and tries to be compatible with it.

Since the original action was written using `node12` for which github dropped supports I decided to write my own action to manage release using a composite action based on bash shell scripts and [`gh`](https://cli.github.com/).

## Setup action
In your desired workflow (`.github/workflows/`), insert the appropriate lines according to your desired workflow.

### Rolling release
This workflow create a release on the latest commit of the pushed branch, it is named after the branch name. If a release already existed, it is deleted and the tag is moved to the new sha1.
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
        uses: nicovince/manage-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          files: <list of files>
          sha1: ${{ github.sha }}
```

### Create release on pushed tag
This workflow creates a release when a tag is pushed to the repository.

```yaml
name: Release Creation on Tag
on:
  push:
    tags: [ '*' ]

jobs:
  release_on_tag:
    runs-on: ubuntu-latest
    name: Release Creation on Tag Push
    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Release
        uses: nicovince/manage-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          files: <list of files>
          tag: ${{ github.ref_name }}
          body: "Creation of release after ${{ github.ref_name }} tag has been pushed to repository."
```

### Update release on creation
This workflow update a release that has been manually created (web interface, github API, ...)

```yaml
name: Upload Artifacts on Release Creation
on:
  release:
    types: [created]

jobs:
  upload_on_release:
    runs-on: ubuntu-latest
    name: Upload artifacts when Release is Created
    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Get Release Name
        id: get-rel-name
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          echo "release_name=$(gh release view ${{ github.ref_name }} --json 'name' -q '.[]')" >> $GITHUB_OUTPUT

      - name: Update Release
        uses: nicovince/manage-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          files: <list of files>
          release: ${{ steps.get-rel-name.outputs.release_name }}
          tag: ${{ github.ref_name }}
```

## Manual invocation
The script `manage-release.sh` can be invoked manually, it relies on `gh` tool to create or update the release depending on the options passed.

Refer to script's help for details on arguments:

```bash
./manage-release.sh --help
```
