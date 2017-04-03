#!/usr/bin/env bats
load common
load ovirt_common
load helpers
load env_setup

FIXTURES="$FIXTURES/ovirt.runtest"
WORKDIR="$FIXTURES"/.lago
PREFIX="$WORKDIR/default"

unset LAGO__START__WAIT_SUSPEND

@test "ovirt.runtest: setup" {
    # As there's no way to know the last test result, we will handle it here
    local suite="$FIXTURES"/suite.yaml

    rm -rf "$WORKDIR"
    cd "$FIXTURES"
    helpers.run_ok "$LAGOCLI" \
        init \
        "$suite"
    helpers.run_ok "$LAGOCLI" start
}


@test "ovirt.runtest: simple runtest" {
    common.is_initialized "$WORKDIR" || skip "Workdir not initiated"
    cd "$FIXTURES"

    testfiles=(
        "001_basic_test.py"
    )

    for testfile in "${testfiles[@]}"; do
        helpers.run_ok "$LAGOCLI" ovirt runtest "$FIXTURES/$testfile"
        helpers.contains "$output" "${testfile%.*}.test_pass"
        helpers.is_file "$PREFIX/$testfile.junit.xml"
        helpers.contains \
            "$(cat $PREFIX/$testfile.junit.xml)" \
            'errors="0"'
    done
}


@test "ovirt.runtest: failing a test fails the run" {
    common.is_initialized "$WORKDIR" || skip "Workdir not initiated"
    cd "$FIXTURES"
    testfiles=(
        "001_basic_failed_test.py"
    )

    for testfile in "${testfiles[@]}"; do
        helpers.run_nook "$LAGOCLI" ovirt runtest "$FIXTURES/$testfile"
        helpers.contains "$output" "${testfile%.*}.test_fail"
        helpers.is_file "$PREFIX/$testfile.junit.xml"
        helpers.contains \
            "$(cat $PREFIX/$testfile.junit.xml)" \
            'failures="1"'
    done
}


@test "ovirt.runtest: error in a test fails the run" {
    common.is_initialized "$WORKDIR" || skip "Workdir not initiated"
    cd "$FIXTURES"
    testfiles=(
        "001_basic_errored_test.py"
    )

    for testfile in "${testfiles[@]}"; do
        helpers.run_nook "$LAGOCLI" ovirt runtest "$FIXTURES/$testfile"
        helpers.contains "$output" "${testfile%.*}.test_error"
        helpers.is_file "$PREFIX/$testfile.junit.xml"
        helpers.contains \
            "$(cat $PREFIX/$testfile.junit.xml)" \
            'errors="1"'
    done
}


@test "ovirt.runtest: test testlib" {
    common.is_initialized "$WORKDIR" || skip "Workdir not initiated"
    cd "$FIXTURES"

    testfiles=(
        "002_testlib.py"
    )

    for testfile in "${testfiles[@]}"; do
        helpers.run_ok "$LAGOCLI" ovirt runtest "$FIXTURES/$testfile"
        helpers.is_file "$PREFIX/$testfile.junit.xml"
        helpers.contains \
            "$(cat $PREFIX/$testfile.junit.xml)" \
            'errors="0"'
    done
}

@test "ovirt.runtest: compare host cpu directly from /proc/cpuinfo" {
    common.is_initialized "$WORKDIR" || skip "Workdir not initiated"
    cd "$FIXTURES"
    helpers.run_ok "$LAGOCLI" \
        shell \
        "lago_functional_tests_host" \
        -c \
        "cat /proc/cpuinfo > /tmp/cpuinfo"
    helpers.run_ok "$LAGOCLI" \
        copy-from-vm \
        "lago_functional_tests_host" \
        /tmp/cpuinfo \
        test_cpu_info
    output=$(gawk 'match($0, /^model name\s+:\s+(.*)$/, a) {print a[1];exit}' test_cpu_info)
    echo "Extracted CPU String: $output"
    helpers.contains "$output" "Westmere"
}


@test "ovirt.runtest: teardown" {
    if common.is_initialized "$WORKDIR"; then
        pushd "$FIXTURES"
        helpers.run_ok "$LAGOCLI" destroy -y --all-prefixes
        popd
    fi
    env_setup.destroy_domains
    env_setup.destroy_nets
}
