#!/bin/bash -e

POSITIONAL_ARGS=()
RELEASE_NAME=""
TAG=""
MESSAGE=""
BODY=""
PRERELEASE=1
DRAFT=0

function delete_old_release()
{
    local release_name="$1"

    release_list="$(gh api repos/{owner}/{repo}/releases -q '.[] | .["tag_name"]')"
    echo "Found releases: ${release_list}"
    if [ ! -z "${release_list}" ]; then
        match=$(echo "${release_list}" | grep "^${release_name}$")
        if [ "${match}" = "${release_name}" ]; then
            echo "Delete relase ${release_name}"
            gh release delete --yes --cleanup-tag "${release_name}"
        fi
    fi
}

function create_release()
{
    local release_name="$1"
    local tag="$2"
    local message="$3"
    local body="$4"
    local prerelease="$5"
    local draft="$6"
    local opts=""

    if [ "${prerelease}" -eq 1 ]; then
        opts="${opts} --prerelease"
    fi

    if [ "${draft}" -eq 1 ]; then
        opts="${opts} --draft"
    fi
    echo "Creating release with:"
    echo "gh release create --title \"${release_name}\" --notes \"${body}\" ${opts} ${tag}"
    gh release create --title "${release_name}" --notes "${body}" ${opts} ${tag}
}

function help()
{
    script_name="$(basename $0)"
    options="[-h|--help]"
    options="${options} [-n|--release-name <release name>]"
    options="${options} [-t|--tag <tag>]"
    options="${options} [-m|--message <message>]"
    options="${options} [-b|--body <body>]"
    options="${options} [-r|--release]"
    options="${options} [-d|--draft]"

    echo "Usage ${script_name} ${options} <FILE1 FILE2 ...>"
    echo ""
    echo "Options:"
    echo ""
    echo "  -h, --help"
    echo "    Display this help and exit"
    echo ""
    echo "  -n, --release-name <release name>"
    echo "    Name of the release to create, use current branch name if not provided."
    echo ""
    echo "  -t, --tag"
    echo "    Name of the tag to use, use release name if not provided."
    echo ""
    echo "  -m, --message"
    echo "    One-line description of the release."
    echo ""
    echo "  -b, --body"
    echo "    Detailed description of the release."
    echo ""
    echo "  -r, --release"
    echo "    Mark the release as a 'release' instead of a pre-release."
    echo ""
    echo "  -d, --draft"
    echo "    Mark the release as a draft."
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      shift
      help
      exit 0
      ;;
  -n|--release-name)
      RELEASE_NAME="$2"
      shift
      shift
      ;;
  -t|--tag)
      TAG="$2"
      shift
      shift
      ;;
  -m|--message)
      MESSAGE="$2"
      shift
      shift
      ;;
  -b|--body)
      BODY="$2"
      shift
      shift
      ;;
  -r|--release)
      PRERELEASE=0
      shift
      ;;
  -d|--draft)
      DRAFT=1
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

echo "POSITIONAL_ARGS=${POSITIONNAL_ARGS[@]}"

if [ -z "${RELEASE_NAME}" ]; then
    RELEASE_NAME="$(git rev-parse --abbrev-ref HEAD)"
fi

if [ -z "${TAG}" ]; then
    TAG="${RELEASE_NAME}"
fi

if [ -z ${MESSAGE} ]; then
    MESSAGE="${RELEASE_NAME} latest release"
fi

echo "RELEASE_NAME=${RELEASE_NAME}"
echo "TAG=${TAG}"
echo "MESSAGE=${MESSAGE}"
echo "BODY=${BODY}"
echo "PRERELEASE=${PRERELEASE}"
echo "DRAFT=${DRAFT}"

if [ "$#" -eq 0 ]; then
    echo "Missing files to add to release"
    exit 1
fi

for f in "${POSITIONAL_ARGS[@]}"; do
    if [ ! -f "${f}" ]; then
        echo "${f} does not exist"
        exit 1
    fi
done

# check gh is logged, this command returns a non-zero exit code when not logged in.
gh auth status

delete_old_release "${RELEASE_NAME}"

create_release "${RELEASE_NAME}" "${TAG}" "${MESSAGE}" "${BODY}" "${PRERELEASE}" "${DRAFT}"
