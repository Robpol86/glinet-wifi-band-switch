load "${BATS_TEST_DIRNAME}/_common.bash"

setup() {
    common_setup
}

@test "requires exactly 1 argument" {
    run ./wifi-band.sh
    assert_failure
    assert_line -p "requires exactly 1 argument"
}
