#!/usr/bin/env bash
set -euo pipefail

# This script replaces the contents of a section with the contents from the annotated
# source address or local file paths inside the DEST file.
# It reads the DEST file into memory and writes the updated content back out.

DEST="../../en/resources/contributing.md"

# track the header level (leading '#' characters)
level=''
# tracks src for curl calls (format: owner/repo path/to/file)
src=''
# tracks file paths for local file reads (final path only)
local=''

# Read entire DEST first and write to DEST at the end to avoid truncation while reading.
while IFS= read -r line; do
  # If we're currently in a replacement region (from a previous anchor),
  # skip lines until we reach the next header at the same level or a horizontal rule.
  if [[ -n "${src}" || -n "${local}" ]]; then
    if [[ "${line}" == ----* ]]; then
      # horizontal rule signals end of replaced section; allow it to be printed below.
      :
    else
      if [[ "${line}" == "${level}"* ]]; then
        # we've reached the next header at the same level: stop replacing
        src=''
        local=''
      else
        # skip old content lines
        continue
      fi
    fi
  fi

  # Reset markers for the current line (we'll set them if this line contains an anchor)
src=''
local=''

  # If line is a header, capture its level (leading # characters)
  if [[ "${line}" == \#* ]]; then
    # Extract leading '#' characters (header level)
    level="${line%%[^#]*}"
  elif [[ "${line}" == '<!-- SRC:'* ]]; then
    # Expect: <!-- SRC: owner/repo path/to/file -->
    tmp="${line#<!-- SRC:}"
    tmp="${tmp%%-->*}"
    # trim whitespace
    tmp="${tmp#"${tmp%%[![:space:]]*}"}"
    tmp="${tmp%"${tmp##*[![:space:]]}"}"
    # tmp now like "owner/repo path/to/file" (best-effort)
src="${tmp}"
  elif [[ "${line}" == '<!-- LOCAL:'* ]]; then
    # Expect: <!-- LOCAL: <label> path/to/local/file -->
    tmp="${line#<!-- LOCAL:}"
    tmp="${tmp%%-->*}"
    tmp="${tmp#"${tmp%%[![:space:]]*}"}"
    tmp="${tmp%"${tmp##*[![:space:]]}"}"
    # The last field is considered the path
    local="${tmp##* }"
  fi

  # Print the current source line
  echo "${line}"

  # If a LOCAL anchor was detected, include the local file's content here with transformations
  if [[ -n "${local}" ]]; then
    if [[ -f "${local}" ]]; then
      # Print the file starting from first H2 (##) or first non-header line,
      # remove GH MD NOTE blocks that start with >[!NOTE] followed by the next line,
      # and convert GH IMPORTANT tag into plain markdown.
      sed -n '/^##\|^[^#]/,$p' "${local}" | \
        sed -E '/^>\[!NOTE\]/{N;d;}' | \
        sed -E 's/> \[!IMPORTANT\]/> **IMPORTANT:** /g'
      echo
    else
      echo "<!-- LOCAL file not found: ${local} -->"
      echo
    fi

  # If a SRC anchor was detected, fetch the file from the given repo/path and include it
  elif [[ -n "${src}" ]]; then
    echo
    # Parse repo and path from src variable:
    # Accept "owner/repo path/to/file" format; if no space present, try best-effort splitting.
    repo="${src%% *}"
    path="${src#* }"
    if [[ "${repo}" == "${src}" ]]; then
      # No space found; try to find first occurrence of owner/repo/... and split after second path segment
      # Fallback: treat everything up to the first space as repo and remainder as path (best-effort)
      # If we still can't determine a path, warn and skip.
      if [[ "${src}" =~ ^([^/]+/[^/]+)/(.*)$ ]]; then
        repo="${BASH_REMATCH[1]}"
        path="${BASH_REMATCH[2]}"
      else
        path=""
      fi
    fi

    if [[ -z "${path}" ]]; then
      echo "<!-- SRC anchor malformed or missing path: ${src} -->"
      echo
    else
      # Fetch raw file from GitHub master branch and transform similar to local:
      if curl -fsS "https://raw.githubusercontent.com/${repo}/master/${path}" | \
        sed -n '/^##\|^[^#]/,$p' | \
        sed "s/^#/&#${level:1}/g" | \
        sed -E "s#(\[[^]]*\])\(([^):#]*)\)#\1(https://github.com/${repo//\//\\/}/blob/master/\2)#g"; then
        echo
      else
        echo "<!-- Failed to fetch or transform SRC: ${repo}/${path} -->" >&2
        echo
      fi
    fi
  fi

done <<<"$(< "${DEST}")" > "${DEST}"