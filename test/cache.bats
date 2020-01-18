setup() {
  export TEST_KEY="cache-tests-key"

  # clean up any old cache file (-f because we don't care if it exists or not)
  rm -f "$TMPDIR$TEST_KEY"
}

@test "initial run is uncached" {
  run ./cache $TEST_KEY echo hello
  [ "$status" -eq 0 ]
  [ $output = "hello" ]
}

@test "works for quoted arguments" {
  run ./cache $TEST_KEY printf "%s - %s\n" flounder fish
  [ "$status" -eq 0 ]
  [ $output = "flounder - fish" ]
}

@test "preserves the status code of the original command" {
  run ./cache $TEST_KEY exit 1
  [ "$status" -eq 1 ]
}

@test "subsequent runs are cached" {
  run ./cache $TEST_KEY echo initial-value
  [ "$status" -eq 0 ]
  [ $output = "initial-value" ]

  run ./cache $TEST_KEY echo new-value
  [ "$status" -eq 0 ]
  [ $output = "initial-value" ]
}

@test "respects a TTL" {
  run ./cache --ttl 1 $TEST_KEY echo initial-value
  [ "$status" -eq 0 ]
  [ $output = "initial-value" ]

  run ./cache --ttl 1 $TEST_KEY echo new-value
  [ "$status" -eq 0 ]
  [ $output = "initial-value" ]

  sleep 1

  run ./cache --ttl 1 $TEST_KEY echo third-value
  [ "$status" -eq 0 ]
  [ $output = "third-value" ]
}
