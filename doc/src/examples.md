# Code Examples
## Hellorld!
```foot
main :: fn {
    @io.stdout 'write_all' "Hellorld!" !
}
```

## Fibonacci Sequence
```foot
fibonacci :: fn n: @fixed 0~91 {
    prev: mut u64 = 0
    cur: mut u64 = 1
    for _: 0 ~ n {
        next := cur + prev %
        prev = cur
        cur = next
    }
    return cur
}

slow_fibonacci :: fn n: @fixed 0~91 -> u64 {
    // this is a bad idea without memoization
    return match n {
        0, 1 => 1
        _ => (slow_fibonacci' (n-1 %) + (slow_fibonacci' (n-2 %)) %
    }
}
```

## Sieve of Eratosthenes
```foot
max_prime :: 0xFFFF
data : [max_prime / 2 + 1] mut bool

main :: fn {
    @io.stdout 'write_all' "2\n" ! // we're only checking odd primes below
    
    limit := @sqrt max_prime + 1
    
    with delta: mut u16 = 3  repeat {
        prime: mut = delta
        with i := prime / 2  if not data[i] {
            @io.stdout 'print' .[ "{}\n", prime ] !
            data[i] = true
        }
        prime = prime + delta %
        while prime <= max_prime {
            data[prime / 2] = true
            prime = prime + delta %
        }
        delta = delta + 2 %
    } while delta < limit
    
    for i := limit/2..data.len {
        if not data[i] {
            @io.stdout 'print' .[ "{}\n", i * 2 + 1 ] !
        }
    }
}
```