## String Lowercasing Function

The `to_lowercase(input: str) -> str` function accepts a UTF-8 string of at most 1 MB and returns the Unicode case-folded lowercase equivalent. If `input` is `None` or an empty string, the function returns an empty string immediately without entering the case-folding path. The 1 MB bound is enforced at the entry point with a `ValueError` raised before any allocation occurs.
