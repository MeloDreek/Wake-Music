#!/bin/bash
# Optional, authenticated upstream corpus. Always copy before allowing writes.
set -euo pipefail
source_root=${1:?Usage: bash prepare-upstream-fixtures.sh TAGLIB_TEST_DATA TEMP_PARENT}
parent=${2:?Usage: bash prepare-upstream-fixtures.sh TAGLIB_TEST_DATA TEMP_PARENT}
fixtures=$(mktemp -d "$parent/fixtures.corpus.XXXXXX")

copy_verified() {
  local name=$1 expected=$2 actual
  if [[ ! -f "$source_root/$name" || -L "$source_root/$name" ]]; then
    echo "Missing regular upstream fixture: $source_root/$name" >&2
    exit 1
  fi
  actual=$(shasum -a 256 "$source_root/$name")
  actual=${actual%% *}
  if [[ "$actual" != "$expected" ]]; then
    echo "SHA-256 mismatch for TagLib 2.3.2 fixture: $name" >&2
    exit 1
  fi
  cp "$source_root/$name" "$fixtures/$name"
}

# Official archive: https://taglib.org/releases/taglib-2.3.2.tar.gz
# Archive SHA-256: 3ca2d8afaa7f1cf7f6ed10e511ebc368bfacd6dcaa3dbfa690b89e502e8963dc
copy_verified empty10ms.dsf f3b2de2c2e783e887771a95aa302496eb3a82fcb606c3276d40650e887a6f9aa
copy_verified empty10ms.dff d7be2c9f3d539dffd49e73a9462a5daba3645ca4b20636f4518c8182ded8f8b5
copy_verified click.mpc 178f44eb55353512ef611ccca4d10557af7c2d329a6078a019a5d66d522d25ad
copy_verified mac-399.ape 8c851b4f52bbbd822262040ae8961b8c27f8f702d1be3fa50cca283d009aadea
copy_verified no-tags.mka 08cf82e5d21838936421cabc2cb10a75587fd3d346cf9139518ac0e02f97f2c7
copy_verified segfault.mpc 20ce5470a50dfb639aec60fcff4ef3f47bdb4004eb61247f3407731d130455f4
copy_verified segfault2.mpc b35f7b7075794c53caf27ea5fe7d6b72971ef782e6901a5db699127543ca60a8
copy_verified infloop.mpc 3159ed965c9eaa113ae1d88b0602eaea47801f10f0a64a4b4ba80b2f2fd392b6
copy_verified zerodiv.mpc 1b5e72f8d40eb42ada0903daac7a3e2dee152ea10205b324b0e6da51658842d3
copy_verified longloop.ape 2aff0c0bd8f8c86d26e65d73141598b93d0e78283e5570a45812200978bea143
copy_verified zerodiv.ape 26b640761e13d7440106df44d5bfd5dfe3ccd804b0a9e4b6aa5a3ac397e72ff8
printf '%s\n' "$fixtures"
