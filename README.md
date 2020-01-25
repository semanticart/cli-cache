# cli-cache

A general-purpose CLI caching script.

```
usage: cache [--ttl SECONDS] [--cache-status CACHEABLE-STATUSES] [cache-key] [command] [args for command]
        --ttl SECONDS   # Treat previously cached content as fresh if fewer than SECONDS seconds have passed
        --cache-status  # Quoted and space-delimited exit statuses for [command] that are acceptable to cache.
        --help          # show this help documentation
```

[Read about the development](https://blog.semanticart.com/tags/cli-cache/).
