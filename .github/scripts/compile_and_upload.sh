#!/bin/bash

set -ex

cd "$(dirname "$0")/../.."

tag=$1

# Ensure tasks are compiled
mix deps.get
mix compile

if gh release list | grep $tag; then
  archive_filename=$(mix xla.info archive_filename)
  build_archive_dir=$(mix xla.info build_archive_dir)

  if gh release view $tag | grep $archive_filename; then
    echo "Found $archive_filename in $tag release artifacts, skipping compilation"
  else
    if [[ $XLA_TARGET == rocm ]]; then
      echo "BUILDING..."
      ./builds/build.sh rocm
      mkdir -p "$build_archive_dir"
      find "$(pwd)/builds/output/$XLA_TARGET" ! -readable -prune -o -type f -name "$archive_filename" -exec cp {} "$build_archive_dir/$archive_filename" \;
      echo "BUILD COMPLETE"
    else
      XLA_BUILD=true mix compile
    fi
    echo "UPLOADING..."
    
    # Uploading is the final action after several hour long build,
    # so in case of any temporary network failures we want to retry
    # a number of times
    for i in {1..10}; do
      gh release upload --clobber $tag "$build_archive_dir/$archive_filename" && break
      echo "Upload failed, retrying in 30s"
      sleep 30
    done
  fi
else
  echo "::error::Release $tag not found"
  exit 1
fi
