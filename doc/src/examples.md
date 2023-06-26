# Code Examples
## Hellorld!
```foot
main :: fn {
    try @io.stdout 'write_all' "Hellorld!"
}
```

## Fibonacci Sequence
```foot
fibonacci :: fn n: u8 {
    prev : mut u64 = 0
    cur : mut u64 = 1
    for _: 0 ~ n {
        next := @narrow cur + prev
        prev = cur
        cur = next
    }
    return cur
}

slow_fibonacci :: fn n: u8 -> u64 {
    // this is a bad idea without memoization :P
    return match n {
        0, 1 => 1
        _ => @narrow (slow_fibonacci' n-1) + (slow_fibonacci' n-2)
    }
}
```

## Sieve of Eratosthenes
```foot
max_prime :: 2^16-1
data : [max_prime / 2 + 1] mut bool

main :: fn {
    try @io.stdout 'write_all' "2\n" // we're only checking odd primes below
    
    limit := @sqrt max_prime + 1
    
    with delta: mut u16 = 3  repeat {
        prime: mut = delta
        with i := prime / 2  if not data[i] {
            try @io.stdout 'print' .[ "{}\n", prime ]
            data[i] = true
        }
        prime = @narrow prime + delta
        while prime <= max_prime {
            data[prime / 2] = true
            prime = @narrow prime + delta
        }
        delta = @narrow delta + 2
    } while delta < limit
    
    for i := limit/2..data.len {
        if not data[i] {
            try @io.stdout 'print' .[ "{}\n", i * 2 + 1 ]
        }
    }
}
```