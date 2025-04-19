bats_load_library "bats-support"
bats_load_library "bats-assert"
bats_load_library "bats-file"

common_setup() {
    TMPDIR="$(temp_make)"

    export MOCK_BINS="$TMPDIR/.bin"
    mkdir "$MOCK_BINS"
    export PATH="$MOCK_BINS:$PATH"

    # Mock logger.
    install -m0755 /dev/stdin "$MOCK_BINS/logger" <<< $'#!/bin/sh\necho $@'
}
