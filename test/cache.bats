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

@test "only caches 0 exit status by default" {
  run ./cache $TEST_KEY exit 1
  [ "$status" -eq 1 ]
  [ ! -f "$TMPDIR$TEST_KEY" ]

  run ./cache $TEST_KEY exit 0
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR$TEST_KEY" ]
}

@test "allows specifying exit statuses to cache" {
  run ./cache --cache-status "1 2" $TEST_KEY exit 0
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR$TEST_KEY" ]

  run ./cache --cache-status "1 2" $TEST_KEY exit 1
  [ "$status" -eq 1 ]
  [ -f "$TMPDIR$TEST_KEY" ]

  rm "$TMPDIR$TEST_KEY"

  run ./cache --cache-status "1 2" $TEST_KEY exit 2
  [ "$status" -eq 2 ]
  [ -f "$TMPDIR$TEST_KEY" ]
}

@test "allows specifying * to allow caching all statuses" {
  run ./cache --cache-status "*" $TEST_KEY exit 3
  [ "$status" -eq 3 ]
  [ -f "$TMPDIR$TEST_KEY" ]
}

@test "returns the cached exit status" {
  run ./cache --cache-status "*" $TEST_KEY exit 3
  [ "$status" -eq 3 ]

  run ./cache --cache-status "*" $TEST_KEY exit 9
  [ "$status" -eq 3 ]
}

@test "documents options with --help" {
  run ./cache --help
  [ "$status" -eq 0 ]
  echo $output | grep -- --ttl
  echo $output | grep -- --cache-status
  echo $output | grep -- --help
}

@test "stops parsing arguments after --" {
  run ./cache --ttl 1 -- $TEST_KEY grep --help
  [ "$status" -eq 2 ]
  echo $output | grep -- "usage: grep"
}
