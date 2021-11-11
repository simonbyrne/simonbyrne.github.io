@def title = "Beware of fast-math"
@def date = "2021-11-18"
@def tags = ["C", "fast-math", "compilers"]

# {{title}}

One of my more frequent rants, both online and in person, is the danger posed by the
"fast-math" compiler flag. While these rants may elicit resigned acknowledgment from
those who already understand the dangers involved, they do little to help those who don't.
So given the remarkable paucity of writing on the topic (including the documentation of
the compilers themselves), I decided it would make a good inaugural topic for this blog.

## So what is fast-math?

It's a compiler flag or option that exists in many languages and compilers, including:

* `-ffast-math` (and included by `-Ofast`) in [GCC](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html) and [Clang](https://clang.llvm.org/docs/UsersManual.html#cmdoption-ffast-math)
* `-fp-model=fast` in [ICC](https://www.intel.com/content/www/us/en/develop/documentation/cpp-compiler-developer-guide-and-reference/top/compiler-reference/compiler-options/compiler-option-details/floating-point-options/fp-model-fp.html)
* `/fp:fast` in [MSVC](https://docs.microsoft.com/en-us/cpp/build/reference/fp-specify-floating-point-behavior?view=msvc-170)
* [`--math-mode=fast` command line option](https://docs.julialang.org/en/v1/manual/command-line-options/#command-line-options) or [`@fastmath` macro](https://docs.julialang.org/en/v1/base/math/#Base.FastMath.@fastmath) in Julia.

So what does it actually do? Well, as the name said, it makes your math faster. That
sounds great, we should definitely do that!

> I mean, the whole point of fast-math is trading off speed with correctness. If fast-math was to give always the correct results, it wouldn’t be fast-math, it would be the standard way of doing math.
&mdash; [Mosè Giordano](https://discourse.julialang.org/t/whats-going-on-with-exp-and-math-mode-fast/64619/7?u=simonbyrne)

The rules of floating point operations are specified in [the IEEE 754 standard](https://en.wikipedia.org/wiki/IEEE_754), which all popular programming languages (mostly) adhere to; compilers are only allowed to perform optimizations which obey these rules. Fast-math allows the compiler to break some of these rules: these breakages may seem pretty innocuous at first glance, but can have significant and occasionally unfortunate downstream effects.

In [GCC](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html), `-ffast-math` (or `-Ofast`) enables the following options: `-fno-math-errno`, `-funsafe-math-optimizations`, `-ffinite-math-only`, `-fno-rounding-math`, `-fno-signaling-nans`, `-fcx-limited-range` and `-fexcess-precision=fast`. Note that `-funsafe-math-optimizations` is itself a collection of options `-fno-signed-zeros`, `-fno-trapping-math`, `-fassociative-math` and `-freciprocal-math`, plus some extra ones, which we will discuss further below.

Now some of these are unlikely to cause problems in most cases: `-fno-math-errno`[^1], `-fno-signaling-nans`, `-fno-trapping-math` disable rarely-used (and poorly supported) features. Others, such as `-freciprocal-math` can reduce accuracy slightly, but are unlikely to cause problems in most cases.

[Krister Walfridsson](https://kristerw.github.io/2021/10/19/fast-math/) gives a very nice
(and somewhat more objective) description of some of these, but I want to focus three in
particular.

## [`-ffinite-math-only`](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html#index-ffinite-math-only)

> Allow optimizations for floating-point arithmetic that assume that arguments and results are not NaNs or +-Infs.

Sounds great! My code doesn't generate any NaNs or Infs, so this shouldn't cause any problems.

But what if your code does generate any intermediate NaNs or Infs, but has internal checks that handles them correctly?

~~~
<iframe width="700px" height="400px" src="https://gcc.godbolt.org/e#z:OYLghAFBqd5QCxAYwPYBMCmBRdBLAF1QCcAaPECAMzwBtMA7AQwFtMQByARg9KtQYEAysib0QXACx8BBAKoBnTAAUAHpwAMvAFYTStJg1AB9U8lJL6yAngGVG6AMKpaAVxYMQAJlIOAMngMmABy7gBGmMQg0gAOqAqEtgzObh7epHEJNgIBQaEsEVHSlpjWSUIETMQEKe6ePiVlAhVVBLkh4ZHRFpXVtWkNvW2BHQVdkgCUFqiuxMjsHACkXgDMgchuWADUiyuOLEwECAB0CLvYixoAgoEEW/yo1LSoh/cTOwDsAEKXV1v/W2ImAIswYWzwCmYDGoE12P2uiw%2BABEOFNaJwAKy8TwcLSkVCcRxbBQzOaYHarHikAiaVFTADW0Q%2Bxw%2BAE4AByrdkY1kadkfLwffScSS8FgSDQaUg4vEEji8BQgKU03Go0hwWAwRAoVAsGJ0SLkShoPUGqLIYBcLg%2BGi0AiRRUQMK00hhQJVACenCpJrYggA8gxaF7VaQsAcjOJQ/ggWUAG6YRWhzCqUque3e3i3TDo0O0PBhYie5xYF0EYh4cXcNVUAzABQANTwmAA7v6YoxMzJBCIxOwpN35Eo1C7dFx9IYTGZ9AXFZApqgYtkGEmALRUKhMBQEVcHI5bVf%2BlYKnOlZf2BhOFx1CQ%2BfwjfKFEArDLxRICfqea2vrJJdqProX0aZcWj6a80m/YDyiGf9OiiIChk/W8elaWCxngqYSVmeY9HLTAFh4NFMWxF05VUdkADZVwoyQtmAZBkC2K1ji8LYIEcUgtlwQgSApFZxy2ZxTXoYg%2BK4CZeBVLQJimBBMCYLAoggBkQAxKVc1FUhxTU6VSM4BUlWpWkpg1bUTX1ESjQgcyzRQDZJy4FZJT4Oh7WIR1nVDN1mGIEMfV1P0CEDYMXXDScozxGMzzwBMkzxFM0wzatyEEHMXXzQtiwwBY8XLStMymWsmHrJtW3bTtkv4HtRHEAcqqHFR1FDXQfAMIwQFMYxzAyudlPxJckjXDctx3PcEAPI8Tysc8IAcJDx3vPI4L0TJ32ScCvx/Na0KfccoOaRCNr0faGFA4YlvQ47DtSTbt1Qh9lvE6ZsP7akgQItVcyxXTQzIyjqNo%2ByjCYlZjg0MG2I4rj8CIUTln4zihIsyI%2BK8CSjNVGTSDkhSuj6jSxVUqUZV4OUDOVYyVIxLwWI0LgPgoqQNFZa0PhfXNjx%2B2V9Ix6SiI4LwSN%2BnmpLpUgE3cpJoiAA%3D"></iframe>
~~~
&mdash; based on [an example from John Regehr](https://twitter.com/johnregehr/status/1440024236257542147)

(to explain what this is showing: the function is setting the return register `eax` to zero, by `xor`-ing it with itself, which means the function will always return `false`)

That's right, your compiler has just removed all those checks.

Depending on who you ask, this is either obvious ("you told the compiler there were no NaNs, so why does it need to check?") or ridiculous ("how can we safely optimize away NaNs if we can't check for them?"). Even compiler developers [can't agree](https://twitter.com/johnregehr/status/1440021297103134720).

##  [`-fassociative-math`](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html#index-fassociative-math)

> Allow re-association of operands in series of floating-point operations.

This allows the compiler to change the order of evaluation in a sequence of floating point operations. For example if you have an expression `(a + b) + c`, it can evaluate it instead as `a + (b + c)`. While these are mathematically equivalent with real numbers, they aren't equivalent in floating point arithmetic: the errors they incur can be different, in some cases quite significantly so:

```
julia> a = 1e9+1; b = -1e9; c = 0.1;

julia> (a+b)+c
1.1

julia> a+(b+c)
1.100000023841858
```

### Vectorization 

So why would you want to do this? One primary reason is that it can enable use of vector/SIMD instructions:

~~~
<iframe width="700px" height="400px" src="https://gcc.godbolt.org/e#z:OYLghAFBqd5QCxAYwPYBMCmBRdBLAF1QCcAaPECAMzwBtMA7AQwFtMQByARg9KtQYEAysib0QXACx8BBAKoBnTAAUAHpwAMvAFYTStJg1AB9U8lJL6yAngGVG6AMKpaAVxYMQAJlIOAMngMmABy7gBGmMQSXKQADqgKhLYMzm4e3nEJSQIBQaEsEVFcMZaY1slCBEzEBKnunj6l5QKV1QS5IeGR0RZVNXXpjX3tgZ0F3cUAlBaorsTI7BwApF4AzIHIblgA1EurjixMBAgAdAh72EsaAIJX11S0qEfbCu5eAKwAbNSPzwBU22qxEmuwA7AAhO7baHbB5PAgvPaQm4w7aBBF4JFQmEKXarAAi2w0Jw0VCxKJh/GI2wgeDxhI0SLReMc2w%2BnyZmK8kO52xBSwh2NRuL2hJFvKBS3e4OZUsJTKFAvxQuImAIcwYiNWyNuoPxHGmtE4714ng4WlIqE4rIUs3mmF2ax4pAImgN0wA1iBJKCTqCAJwADjWgfe/o0gdBXlB%2Bk4kl4LAkGg0pDNFqtHF4ChAKdd5oNpDgsBgiBQqBYsTokXIlDQFarUWQwGKPhotAIkWzEDCbtIYUC1QAnpxnXW2IIAPIMWjD/OkLCHIziOf4VXlABumGzc8wqjKrg7I946MwRrntDwYWIQ%2BcWF7BGIeET3ALDyYwAUADU8JgAO4T2JGCPGRBBEMR2CkED5CUNRe10GIDCMEBTGMcwLzCbNIGmVBYhsARtwAWgnVYs1PMo8M8CAHAGTwYn8UZ8kKPR4kSCiaOYrIKI6RiJgsMjmgYVp%2Bhceo9CaCihJGPIuiKXo2nYkphm4mSJGmW05gWPQH0wRYeENY1TV7DNVEDT4CM%2BSRtmAZBkG2YoTi8GlHFIbZcEIEhHVWGJtmcet6GpFYvMmXg8y0SZpgQTAmCwKIIE9EB3hTM941IRNEtTIzOCzHMXTdaYi1LOtK38msICKhsUGbLhWzoDtiC7Hs537ZhiFnUdy3HAgpxnXsF0MYBlwtVdyLwTdtwtXd90PF9yEEU9e3Q69WtvRYLQfJ8j2mN8P2/P8AKAmb%2BFA0RxEgo7oJUdQ510HxEJMMx9EvTC4stXDkkI4jtgIqgqCYBQCAIw5jlIqwKPsBgnBE9I6Ih5TxlkljshSKHaMyVjkjhpiSn4iThgUvjQYqJSGJUxT5JRsTiek%2BHVJmDSIJdVVdILM8TQyudjNM8zLOs2z7MciBnNc/AiACp0XN84rIk8rxgty/NwtISLou6F7koTBKUzTXgM2y3M8vi94vAcjQuFBT4pA0f1qtBVZYw4Ej2fTLL5bC/SOC8QyOZd0L3VITd6uSb0gA"></iframe>
~~~

For those who aren't familiar with SIMD operations (or reading assembly), I'll try to explain briefly what is going on here (others can skip this part). Since raw clock speeds haven't been getting much faster, one way in which processors have been able to increase performance is through operations which operate on a "vector" (basically, a short sequence of values contiguous in memory).

In this case, instead of performing a sequence of floating point additions (`addss`), it is able to make use of a SIMD instruction (`addps`) which takes vector `float`s (4 in this case, but it can be up to 16 with AVX 512 instructions), and adds them element-wise to another vector in one operation. It does this for the whole array, followed by a final reduction step where to sum the vector to a single value. This means that instead of evaluating

```
s = arr[0] + arr[1];
s = s + arr[2];
s = s + arr[3];
...
s = s + arr[255];
```

it is actually doing

```
s0 = arr[0] + arr[4]; s1 = arr[1] + arr[5]; s2 = arr[2] + arr[6];  s3 = arr[3] + arr[7];
s0 = s0 + arr[8];     s1 = s1 + arr[9];     s2 = s2 + arr[10];     s3 = s3 + arr[11]);
...
s0 = s0 + arr[252];   s1 = s1 + arr[253];   s2 = s2 + arr[254];    s3 = s3 + arr[255]);
sa = s0 + s1;
sb = s2 + s3;
s = sa + sb;
```

where each line corresponds to one floating point instruction.

The problem here is that the compiler generally isn't allowed to make this optimization:
it requires evaluating the sum in a different association grouping than was specified in
the code, and so can give different results. Though in this case it is likely harmless (or
may even improve accuracy[^2]), this is not always the case.

### Compensated arithmetic

Certain algorithms however depend very strictly on the order in which floating point
operations are performed. In particular _compensated arithmetic_ operations make use of it
to compute the error that is incurred in intermediate calculations, and correct for that
in later computations.

The most well-known algorithm which makes use of this is [Kahan
summation](https://en.wikipedia.org/wiki/Kahan_summation_algorithm), which corrects for
the round off error incurred at addition step in the summation loop. We can compile an
implementation of Kahan summation with `-ffast-math`, and compare the result to the simple loop summation
above:

~~~
<iframe width="700px" height="600px" src="https://gcc.godbolt.org/e#z:OYLghAFBqd5TKALEBjA9gEwKYFFMCWALugE4A0BIEAZgQDbYB2AhgLbYgDkAjF%2BTXRMiAZVQtGIHgBYBQogFUAztgAKAD24AGfgCsp5eiyagA%2BudTkVjVEQJDqzTAGF09AK5smUgMzknADIETNgAcp4ARtikIABM5AAO6ErE9kyuHl6%2BicmpQkEh4WxRMfHW2LZpIkQspEQZnt48fuWVQtW1RAVhkdFxVjV1DVnNA53dRSVxAJRW6O6kqJxcNPToLEQA1EqetGsbmwBUm7Wk05sApADsAEIXWgCCm8%2Bbq%2BtbShc%2Bd48vm8FbAhfH5PF5KS4%2BAAimy0ADotDRgfdQc9BKRNhACBDoVpgf8Ic5NrEAKwANjxQNidypm3O1xBf2e4K%2B0OZNNOF2JN3xnOheORL2ukIFz1I2CICyY2yRjyFyK4s3o3GJ/G8XB05HQ3EJSnmi2wl1iPj45CI2gVswA1iBiVpDNxpPw2Da7WqNVquPwlCA7Wb1QryHBYCgMGwEgxopRqKHw4wYqhgDwePE6PQiNFvRAIubyBFgrUAJ7cE2hjjCADyTHoRf95BwbGMwEktcIYsqADdsN7a9h1BV3Oni/wAdglbX6AQIqRC64cDmiKQCM7eAHVixgEoAGoEbAAd3LCWYQ7kwjEEk4MhPihUGhz%2Bh4hkbIHMpksE4i3sgs3QCTsQm7AC05Y%2BJsAE0DQLBKEQAENkQSBeqOFR/t4EBOMMTT%2BEwmATL0MQPkkKTIehBgEXkTA4cUfQPq0yEdEMbiNAYNFVIMXTBD0lF4WM9GZBhUHjOxkxUbMuoLEsBgLtgyx8IqyqqjmHrqAAHKSAGktImzAKgqCbEmsKxBizjkJs%2BDEGQhrGsZrhhhG6IXEaPDTPwfo6NMsxINgLA4DEEBWi69pcI65BuvwHpej6prmm5AWxE6IA%2BNIsKkjwWjSFcJLSDwtpXFofghZq3DOVFgaIEGyBoFgeCECQFBULQEasBwx6CKe4iSJeLXXmomi1vo8RGCYz4WHMYnLG8Bw7GwpiWiwSDGHs7xHCcpBnJctwiqi%2BwfMZlibEQxkFjKKL/MI/xHX8zJQpsOksjC8KIt8G2vOZmLYjCFIEkSZIUvZ1LcnS62/IyBZvRyXJAsS0IAdd52Mlst1styh2PUDfw3VdEBbNDSjnNDyMMoyl3QkQsNrcKqNihKpBSp8KMPHKjwBmOKrBQp2rbHqSwWbFkX%2BtFHleX0vnkNatoBUFzo%2BFcsLEqztZhVYEUuQGZUQCG6A2XGUYQDGtloImyYCAw6akJm2a1nmrCkDWJYa2WRCVtWOb1o2zYaq2SEEJ23Yar2/aDiulDCKOObvtO1uzssGoLkuQ6zGuG7bnuB5HoHnVnu1sidco3V3v0A1mMN76fsLP7IYBwGgeBkHQbB8FWIhbQoWhDEjJh2GCbhJG5ERrcYaRyEUVM1GN7RrHESPNhjwJhRd9R4990xrFD8JI36v0knSUzcly%2B63DKap6madpuk8PphnGaZNXc1ZGuxtE3NObzrnuZ53nUH5YtjkF%2BUK96vpRVklwHmktYjwjJDwAAnJlEkWVIHqV3qFQqz8ValRQIQcC2t05tQvFneQOdbzjiQN6B89BiEYJoEQAsh4IqkGIf0OhSgKFUJoVoIBLNf7cEhAQcCmwk67gfgfNSGktI6T0gZds4IhFH1EaffSRU%2BZAIlvFHwsIfDqI0ZozRiCCqekVgAxRIspBaDhCYsx5jzGkO4D4eS8tkHK2ip2U2aQQDSCAA"></iframe>
~~~

It gives _exactly_ the same assembly as the original summation code above. It reassociates
the addition, then removes a bunch of the terms which are now deemed to be redundant, and
so it optimizes back to a SIMD summation loop.

Compensated arithmetic is typically used in pretty low-level code such as math libraries,
where it is used to get extra precision for intermediate calculations. Fast-math may
just optimize the whole lot away.

## Flushing subnormals to zero

This one is by far the most insidious, as it can affect code compiled _without_ fast-math, and is only cryptically documented under `-funsafe-math-optimizations`:

> When used at link time, it may include libraries or startup files that change the default FPU control word or other similar optimizations.

So what does that mean? Well this is referring to one of those slightly annoying edge
cases of floating point numbers, _subnormals_ (sometimes called _denormals_). [Wikipedia gives a decent
overview](https://en.wikipedia.org/wiki/Subnormal_number), but for our purposes the main
thing you need to know is (a) they're _very_ close to zero, and (b) when encountered, they
can incur a significant performance penalty on many processors (here is a [good
description of why that is the case](https://stackoverflow.com/a/54938328)).

A simple solution to this problem is "flush to zero" (FTZ): that is, if a result would
return a subnormal value, return zero instead. This is actually fine for a lot of use
cases, and this setting is commonly used in audio and graphics applications. But there are
plenty of use cases where it isn't fine: FTZ breaks some important floating point error
analysis results, such as the [Sterbenz
Lemma](https://en.wikipedia.org/wiki/Sterbenz_lemma), and so unexpected results (such as
iterative algorithms failing to converge) may occur.

The problem is how FTZ actually implemented on most hardware: it is not set
per-instruction, but instead [controlled by the floating point
environment](https://software.intel.com/content/www/us/en/develop/documentation/cpp-compiler-developer-guide-and-reference/top/compiler-reference/floating-point-operations/understanding-floating-point-operations/setting-the-ftz-and-daz-flags.html):
more specifically, it is controlled by the floating point control register, which on most
systems is set at the thread level: enabling FTZ will affect all other
operations in the same thread.

GCC with `-funsafe-math-optimizations` enables FTZ (and its close relation, denormals-are-zero, or DAZ), even when building shared
libraries. That means simply loading a shared library can change the results in completely
unrelated code, which is [a fun debugging
experience](https://github.com/JuliaCI/BaseBenchmarks.jl/issues/253#issuecomment-573589022).

##  What can programmers do?

I've joked on Twitter that "friends don't let friends use fast-math", but with the luxury
of a longer format, I will concede that it has  valid use cases. Primarily,
it can actually give valuable performance improvements, and as SIMD lanes get wider and
instructions get fancier, the value of these optimizations will only increase. So when and
how can it be safely used?

Firstly, if you don't care about the accuracy of the results: I come from a scientific
computing background where the primary output of a program is a bunch of numbers. But
floating point arithmetic is used in many domains where that is not the case, such as
audio, graphics, games, and machine learning. I'm not particularly familiar with
requirements in these domains, but there is an interesting rant from [Linus Torvalds 20
years ago](https://gcc.gnu.org/legacy-ml/gcc/2001-07/msg02150.html), arguing that overly
strict floating point semantics are of little importance outside scientific
domains. Nevertheless, [some
anecdotes](https://twitter.com/supahvee1234/status/1382907921848221698) suggest fast-math
can cause issues, so it is probably still useful understand what it does and
why. If you work in these areas, I would love to hear about your experiences, especially
if you identified which of these optimizations has a positive or negative impact.

In cases where you do care about the numerical accuracy of the output, fast-math still
give very useful valuable improvements.  In fact, as newer processors are adding wider
SIMD operations, the optimizations it enables are become increasingly valuable.
At the very least, it can provide a useful reference for what performance is left on the
table. A typical process might be:

1. Develop reliable validation tests

2. Develop useful benchmarks

3. Enable fast-math and compare benchmark results

4. Selectively enable/disable fast-math optimizations to identify

    a. which optimizations have a performance impact, and
    
    b. where in the code that impact arises

5. Validate the final numeric results

Additionally, you can look into alternative mechanisms to obtain optimizations: for SIMD
operations in particulat, tools such as
[OpenMP](https://www.openmp.org/spec-html/5.0/openmpsu42.html) or
[ISPC](https://ispc.github.io/) provide constructions to write code that is amenable to
automatic SIMD optimizations. Julia provides the [`@simd`
macro](https://docs.julialang.org/en/v1/base/base/#Base.SimdLoop.@simd), though this also
has some important caveats on its use.

Alternatively, one can manually use SIMD intrinsics: these are commonly used in
libraries, often with the help of code generation (for example [FFTW](http://fftw.org/)),
but this requires considerably more effort and expertise, and can be difficult to port to
new platforms.

## What can language and compilers developers do?

Firstly, GCC should address the FTZ issue: the bug has been [open for 9 years, but is
still marked NEW](https://gcc.gnu.org/bugzilla/show_bug.cgi?id=55522). At the very least,
this behavior should be more clearly documented, and have a specific option to disable it.

Beyond that, there are 2 primary approaches: educate users, and provide finer control over
the optimizations.

The easiest way to educate users is to give it a better name. Rather than "fast-math",
something like "unsafe-math". Documentation could also be improved to educate users on the
consequences of these choices (consider this post to be my contribution to toward that
goal). Linters and compiler warnings could, for example, warn users that their `isnan`
checks are now useless, or even just highlight which regions of code have been impacted by
the optimizations.

Secondly, languages and compilers need to provide better tools to get the job
done. Ideally these behaviors shouldn't be enabled or disabled via a compiler flag, which
is a very blunt tool, but specified in the code itself, for example

* Both GCC and Clang let you [enable/disable optimizations on a per-function basis](https://stackoverflow.com/a/40702790/392585): these should be standardized to work with all compilers.

* There should be options for even finer control, such as a pragma or macro so that users can assert that "under no circumstances should this `isnan` check be removed/this arithmetic expression be reassociated".

* Conversely, a mechanism to flag certain addition or subtraction operations which the compiler is allowed to reassociate (or contract into a fused-multiply-add operation) regardless of compiler flags.[^3] 

Fundamentally, I think the widespread use of fast-math should be considered a fundamental design
failure: by failing to provide programmers with features they need to make the best use of
modern hardware, programmers are instead encouraged to enable an option that is known to
be blatantly unsafe.


[^1]: Apparently `-fno-math-errno` in GCC [can affect `malloc`](https://twitter.com/kwalfridsson/status/1450556903994675205), so may not be quite so harmless.

[^2]: One of the simplest results in numerical analysis is that [the error bound on summation is proportional to the sum of the absolute values of the intermediate sums](https://www.google.com/books/edition/Accuracy_and_Stability_of_Numerical_Algo/5tv3HdF-0N8C?hl=en&gbpv=1&pg=PA82&printsec=frontcover). SIMD summation splits the accumulation over multiple values, so will typically give smaller intermediate sums.

[^3]: Rust provides something like this via [experimental intrinsics](https://stackoverflow.com/a/40707111/392585), though I'm not 100% clear on what optimzations are allowed.