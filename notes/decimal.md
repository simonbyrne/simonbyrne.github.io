# It's fine to use binary floats for currency

One of the most popular statments

> You should never use floats to represent currency!

The obvious counter example to this is Microsoft Excel. Arguably the most widely used programming language in the world, and upon which every financial institution is entirely dependent, it exclusively uses 64-bit binary floats to represent all numeric values (albeit with some modifications).


# Why don't more languages have decimal types?

There are 3 main cases
- Fixed point decimal: COBOL and databases
- IEEE754 decimal: IBM POWER & z Systems provide hardware support, otherwise provided by 3rd party libraries (such as https://www.intel.com/content/www/us/en/developer/articles/tool/intel-decimal-floating-point-math-library.html)
- Arbitrary-precision decimal