setup() {
  export TEST_KEY="cache-tests-key"
  export CACHE_DIR=${CACHE_DIR:-$TMPDIR}
  export LAST_SECOND=""

  # clean up any old cache file (-f because we don't care if it exists or not)
  rm -f "$CACHE_DIR$TEST_KEY"
}

wait_for_second_to_pass() {
	now=$(date +%s)

	if [ -z "$LAST_SECOND" ]; then
		LAST_SECOND=$now
	else
		if [ "$now" -gt "$LAST_SECOND" ]; then
			return 0
		fi
	fi

	wait_for_second_to_pass
}

@test "initial run is uncached" {
  run ./cache $TEST_KEY echo hello
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}

@test "works for quoted arguments" {
  run ./cache $TEST_KEY printf "%s - %s\n" flounder fish
  [ "$status" -eq 0 ]
  [ "$output" = "flounder - fish" ]
}

@test "preserves the status code of the original command" {
  run ./cache $TEST_KEY exit 1
  [ "$status" -eq 1 ]
}

@test "subsequent runs are cached" {
  run ./cache $TEST_KEY echo initial-value
  [ "$status" -eq 0 ]
  [ "$output" = "initial-value" ]

  run ./cache $TEST_KEY echo new-value
  [ "$status" -eq 0 ]
  [ "$output" = "initial-value" ]
}

@test "respects a TTL" {
  run ./cache --ttl 1 $TEST_KEY echo initial-value
  [ "$status" -eq 0 ]
  [ "$output" = "initial-value" ]

  run ./cache --ttl 1 $TEST_KEY echo new-value
  [ "$status" -eq 0 ]
  [ "$output" = "initial-value" ]

  wait_for_second_to_pass

  run ./cache --ttl 1 $TEST_KEY echo third-value
  [ "$status" -eq 0 ]
  [ "$output" = "third-value" ]
}

@test "only caches 0 exit status by default" {
  run ./cache $TEST_KEY exit 1
  [ "$status" -eq 1 ]
  [ ! -f "$CACHE_DIR$TEST_KEY" ]

  run ./cache $TEST_KEY exit 0
  [ "$status" -eq 0 ]
  [ -f "$CACHE_DIR$TEST_KEY" ]
}

@test "allows specifying exit statuses to cache" {
  run ./cache --cache-status "1 2" $TEST_KEY exit 0
  [ "$status" -eq 0 ]
  [ ! -f "$CACHE_DIR$TEST_KEY" ]

  run ./cache --cache-status "1 2" $TEST_KEY exit 1
  [ "$status" -eq 1 ]
  [ -f "$CACHE_DIR$TEST_KEY" ]

  rm "$CACHE_DIR$TEST_KEY"

  run ./cache --cache-status "1 2" $TEST_KEY exit 2
  [ "$status" -eq 2 ]
  [ -f "$CACHE_DIR$TEST_KEY" ]
}

@test "allows specifying * to allow caching all statuses" {
  run ./cache --cache-status "*" $TEST_KEY exit 3
  [ "$status" -eq 3 ]
  [ -f "$CACHE_DIR$TEST_KEY" ]
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
  echo "$output" | grep -- --ttl
  echo "$output" | grep -- --cache-status
  echo "$output" | grep -- --stale-while-revalidate
  echo "$output" | grep -- --help
}

@test "stops parsing arguments after --" {
  run ./cache --ttl 1 -- $TEST_KEY grep --help

  if [[ "$OSTYPE" == "darwin"* ]]; then
	[ "$status" -eq 2 ]
	echo "$output" | grep -- "usage: grep"
  else
	[ "$status" -eq 0 ]
	echo "$output" | grep -- "Usage: grep"
  fi
}

@test "parses options before and after the cache key" {
  # fails because the status isn't allowed by our options
  run ./cache --cache-status "2" $TEST_KEY exit 0
  [ "$status" -eq 0 ]
  [ ! -f "$CACHE_DIR$TEST_KEY" ]

  # succeeds because the status is allowed by our option before the
  # cache key
  run ./cache --cache-status "0 2" $TEST_KEY exit 2
  [ "$status" -eq 2 ]
  [ -f "$CACHE_DIR$TEST_KEY" ]

  rm "$CACHE_DIR$TEST_KEY"

  # succeeds because the status is allowed by our option after the
  # cache key
  run ./cache $TEST_KEY --cache-status "0 2" exit 2
  [ "$status" -eq 2 ]
  [ -f "$CACHE_DIR$TEST_KEY" ]
}

@test "stops parsing options after the command starts" {
  run ./cache $TEST_KEY echo --ttl 1 --help
  [ "$status" -eq 0 ]
  [ "$output" = "--ttl 1 --help" ]
}

@test "--stale-while-revalidate does not trigger a background update if we're in the TTL" {
  run ./cache --stale-while-revalidate 1 --ttl 1 $TEST_KEY echo 1
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  [ -f "$CACHE_DIR$TEST_KEY" ]

  run ./cache --stale-while-revalidate 1 --ttl 1 $TEST_KEY echo 2
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]

  [ "$(cat "$CACHE_DIR$TEST_KEY")" = "1" ]
}

@test "--stale-while-revalidate triggers a background update if we're outside the TTL but inside the SWR seconds" {
  run ./cache --stale-while-revalidate 1 --ttl 1 $TEST_KEY echo 1
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  [ -f "$CACHE_DIR$TEST_KEY" ]

  wait_for_second_to_pass

  run ./cache --stale-while-revalidate 1 --ttl 1 $TEST_KEY echo 2
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]

  [ "$(cat "$CACHE_DIR$TEST_KEY")" = "2" ]

  # and now the updated value is used
  run ./cache --stale-while-revalidate 1 --ttl 1 $TEST_KEY echo 3
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "--stale-while-revalidate falls back to synchronous behavior if we're outside the TTL and SWR seconds" {
  run ./cache --stale-while-revalidate 1 --ttl 1 $TEST_KEY echo 1
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]

  wait_for_second_to_pass

  run ./cache --stale-while-revalidate 1 --ttl 0 $TEST_KEY echo 2
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}
