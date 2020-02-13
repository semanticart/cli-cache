# cli-cache

A general-purpose CLI caching script. Throw it in your $PATH and cache away.

```
usage: cache [--ttl SECONDS] [--cache-status CACHEABLE-STATUSES] [--stale_while_revalidate SECONDS] [cache-key] [command] [args for command]
        --ttl                     # Treat previously cached content as fresh if fewer than SECONDS seconds have passed
        --cache-status            # Quoted and space-delimited exit statuses for [command] that are acceptable to cache.
        --check                   # Returns 0 if the content is cached and 1 if content is uncached or the TTL/SWR conditions are unmet.
        --purge                   # Remove any cached content at [cache-key]
        --stale-while-revalidate  # Serve stale content for SECONDS past TTL while updating in the background
        --help                    # show this help documentation
```

[Read about the development](https://blog.semanticart.com/tags/cli-cache/).
