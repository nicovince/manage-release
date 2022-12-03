#!/bin/bash -e

POSITIONAL_ARGS=()
RELEASE_NAME=""
TAG=""
SHA1=""
MESSAGE=""
BODY=""
PRERELEASE=1
DRAFT=0

function log()
{
    echo "$1" >&2
}

function release_exist()
{
    local release_name="$1"
    local ret="0"

    release_list="$(gh api repos/{owner}/{repo}/releases -q '.[] | .["name"]')"
    log "Found releases: ${release_list}"
    if [ ! -z "${release_list}" ]; then
        match=$(echo "${release_list}" | grep "^${release_name}$")
        if [ "${match}" = "${release_name}" ]; then
            ret="1"
        else
            ret="0"
        fi
    else
        ret="0"
    fi
    if [ ${ret} -eq 0 ]; then
        log "Release ${release_name} does not exist"
    else
        log "Release ${release_name} exists"
    fi
    echo ${ret}
}

function get_release_tag()
{
    local release_name="$1"
    tag_name=$(gh api repos/{owner}/{repo}/releases -q ".[] | select(.name == \"${release_name}\") | .[\"tag_name\"]")
    echo "${tag_name}"
}

function is_release_on_tag()
{
    local release_name="$1"
    local tag="$2"
    local release_tag="$(get_release_tag "${release_name}")"

    if [ "${tag}" = "${release_tag}" ]; then
        log "release ${release_name} is on requested tag ${tag}"
        echo 1
    else
        log "release ${release_name} is not on requested tag ${tag} but on ${release_tag}"
        echo 0
    fi
}

function tag_exists()
{
    local tag="$1"
    tag_list="$(git tag --list)"
    match="$(echo "${tag_list}" | grep "^${tag}$")"
    if [ "${match}" = "${tag}" ]; then
        echo 1
    else
        echo 0
    fi
}

function get_sha1()
{
    local ref="$1"
    echo "$(git log -1 --pretty=format:%H ${ref})"
}

function delete_release()
{
    local release_name="$1"

    log "Delete release ${release_name}"
    gh release delete --yes --cleanup-tag "${release_name}"
}

function create_release()
{
    local release_name="$1"
    local tag="$2"
    local message="$3"
    local body="$4"
    local prerelease="$5"
    local draft="$6"
    local sha1="$7"
    local opts=""

    if [ "${prerelease}" -eq 1 ]; then
        opts="${opts} --prerelease"
    fi

    if [ "${draft}" -eq 1 ]; then
        opts="${opts} --draft"
    fi
    log "Create release ${release_name} on ${tag} at ${sha1}"
    gh release create --target "${sha1}" --title "${release_name}" --notes "${body}" ${opts} ${tag}
    git fetch
}

function upload_assets()
{
    local tag="$1"

    log "Upload assets to release tagged at ${tag}"
    gh release upload --clobber "${tag}" "${POSITIONAL_ARGS[@]}"
}

function help()
{
    script_name="$(basename $0)"
    options="[-h|--help]"
    options="${options} [-n|--release-name <release name>]"
    options="${options} [-t|--tag <tag>]"
    options="${options} [-s|--sha1]"
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
    echo "  -s, --sha1"
    echo "    SHA1 where the tag must be set, use SHA1 of tag if not provided."
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
  -s|--sha1)
      SHA1="$2"
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
    RELEASE_NAME="$(git rev-parse --abbrev-ref HEAD | sed 's#heads/##')"
fi

if [ -z "${TAG}" ]; then
    TAG="${RELEASE_NAME}"
fi

if [ -z "${SHA1}" ]; then
    if [ "$(tag_exists "${TAG}")" -eq 1 ]; then
        SHA1="$(get_sha1 "tags/${TAG}")"
    else
        SHA1="$(git log -1 --pretty=format:%H)"
    fi
else
    # Make sure we have a full SHA1
    SHA1="$(git log -1 --pretty=format:%H ${SHA1})"
fi


if [ -z "${MESSAGE}" ]; then
    MESSAGE="${RELEASE_NAME} latest release"
fi

if [ -z "${BODY}" ]; then
    BODY="${RELEASE_NAME} latest release"
fi

echo "RELEASE_NAME=${RELEASE_NAME}"
echo "TAG=${TAG}"
echo "SHA1=${SHA1}"
echo "MESSAGE=${MESSAGE}"
echo "BODY=${BODY}"
echo "PRERELEASE=${PRERELEASE}"
echo "DRAFT=${DRAFT}"


if [ "$#" -eq 0 ]; then
    log "Missing files to add to release"
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

git tag --list
git branch
if [ "$(release_exist "${RELEASE_NAME}")" -eq "1" ]; then
    if [ "$(is_release_on_tag "${RELEASE_NAME}" "${TAG}")" -eq 1 ]; then
        tag_sha1="$(get_sha1 "tags/${TAG}")"
        if [ "${tag_sha1}" = "${SHA1}" ]; then
            log "Update existing release"
        else
            git tag --delete "${TAG}"
            delete_release "${RELEASE_NAME}"
            create_release "${RELEASE_NAME}" "${TAG}" "${MESSAGE}" "${BODY}" "${PRERELEASE}" "${DRAFT}" "${SHA1}"
        fi
    else
        log "Error: Release to modify must be on expected tag"
        exit 1
    fi
else
    if [ "$(tag_exists "${TAG}")" -eq 1 ]; then
        tag_sha1="$(get_sha1 "tags/${TAG}")"
        if [ "${tag_sha1}" = "${SHA1}" ]; then
            create_release "${RELEASE_NAME}" "${TAG}" "${MESSAGE}" "${BODY}" "${PRERELEASE}" "${DRAFT}" "${SHA1}"
        else
            log "Error: Requested release with tag ${TAG} on ${SHA1}, but tag already exists on ${tag_sha1}"
            exit 1
        fi
    else
        create_release "${RELEASE_NAME}" "${TAG}" "${MESSAGE}" "${BODY}" "${PRERELEASE}" "${DRAFT}" "${SHA1}"
    fi
fi
upload_assets "${TAG}"
