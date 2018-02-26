#!/bin/bash

set -e

. ./plover_build_utils/functions.sh

download()
{
  name="$1"
  url="$2"
  md5="$3"

  dst="$downloads/$name"
  for retry in $(seq 3)
  do
    if ! [ -r "$dst" ]
    then
      [ -d "$downloads" ] || run mkdir -p "$downloads"
      if ! run curl --show-error --silent -o "$dst" "$url"
      then
        err "$name download failed"
        run rm -f "$dst"
        continue
      fi
    fi
    if [ $opt_dry_run -eq 0 ] && [ "$(md5 -q "$dst")" != "$md5" ]
    then
      err "$name md5 did not match"
      run rm -f "$dst"
      continue
    fi
    return 0
  done
  return 1
}

setup()
{
  # Install Python.
  download 'python36.pkg' 'https://www.python.org/ftp/python/3.6.2/python-3.6.2-macosx10.6.pkg' '86e6193fd56b1e757fc8a5a2bb6c52ba'
  run sudo installer -pkg "$downloads/python36.pkg" -target /
  # Update certifiates.
  run '/Applications/Python 3.6/Install Certificates.command'
  # Setup development environment.
  bootstrap_dev --user
}

build()
{
  run git fetch --quiet --unshallow
  run "$python" setup.py patch_version
  run "$python" setup.py test
  run "$python" setup.py bdist_dmg
  run mv dist/*.dmg "$CIRCLE_ARTIFACTS/"
}

deploy()
{
  artifact="$(echo -n "$CIRCLE_ARTIFACTS"/*.dmg)"
  github_release="$downloads/circle_github_release_darwin-amd64.tar.bz2"
  github_release_url='https://github.com/aktau/github-release/releases/download/v0.7.2/darwin-amd64-github-release.tar.bz2'
  github_release_sha1='16d40bcb4de7e29055789453f0d5fdbf1bfd3b49'
  github_release_exe='./bin/darwin/amd64/github-release'
  github_release_opts=(--user openstenoproject --repo plover --tag "$("$python" ./setup.py --version)")
  run [ -r "$artifact" ]
  run "$python" -m plover_build_utils.download "$github_release_url" "$github_release_sha1" "$github_release"
  run tar xvjf "$github_release"
  run "$github_release_exe" release "${github_release_opts[@]}" --draft
  run "$github_release_exe" upload "${github_release_opts[@]}" --file "$artifact" --name "${artifact#*/}"
}

[ "$CIRCLE_BUILD_IMAGE" == 'osx' ]
[ $# -eq 1 ]

python='python3'

"$1"
