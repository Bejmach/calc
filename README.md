# Calc (temp name)

calculator with raylib gui

correctly handles order of operations and allows functions and constants like
sin(x), pow(x, y), PI, TAN

because of the limitations of odin language, which lack in decimal type, the
calculator works on f64 which can produce floating point error when number is
longer than ~15 digits

Requirements: odin, raylib

Instalation

```
odin build .
```

and add to path

I will finish nixos flake soon to allow for adding it to inputs probably

If you found some operation that should work but doesn't, run
`calc --debug --headless "<func>"` and send an issue with provided function and
output

Im bad at writing detailed docs...
