# Overflow Casts
If a value needs to be cast from a "larger" type to a "smaller" one (i.e. where some possible values in the source type are outside the range of the the destination type), then the conversion cannot be done implicitly, and a cast is required.
* `%` operator: adds a safety-check assert that the value is valid in the new type
* `@trunc`: truncate the result to the required number of bits (only works when the result type is a full-range fixed-point number)
* `@wrap`: same as `@trunc` for full-range types, but this works on non-full-range types as well (albeit less performantly).
* `@saturate`: clamp the value to the bounds of the destination type

# Rounding Casts
* `%` operator: adds a safety-check assert that the value is in the new type
* `@round`: round according to the result type's rounding mode
