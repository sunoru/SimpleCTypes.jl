# SimpleCTypes.jl

[![CI](https://github.com/sunoru/SimpleCTypes.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/sunoru/SimpleCTypes.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/github/sunoru/SimpleCTypes.jl/branch/main/graph/badge.svg?token=dufUA8AXK6)](https://codecov.io/github/sunoru/SimpleCTypes.jl)

`SimipleCTypes.jl` is a zero-dependency Julia package that provides some simple definitions of C types, specifically:

- `CfuncPtr` for C function pointers
- `Carray` for fixed-size C arrays
- `Cunion` for C-style unions

It is mainly used in the type definitions of Julia bindings for C libraries.
All types are immutable so that they can have the same memory layout as in C.

## Usage

## `CfuncPtr` and `@cfunc`

`CfuncPtr` can be used to replace `Ptr{Cvoid}` in `ccall` and struct definitions,
so that you can pass a function pointer around in a type-safe way.
It takes two type parameters, the return type and the argument types of the function.

```c
struct foo {
    int (*f)(int, int);
};
```

can be defined in Julia as:

```julia
struct Foo
    f::CfuncPtr{Cint,Tuple{Cint,Cint}}
end
```

You can use `@cfunc` to create a `CfuncPtr` from a Julia function,
its usage is the same as `@cfunction`:

```julia
f(x) = 2x
fptr, _ = @cfunc(f, Cint, (Cint,))
fptr2, cf = @cfunc($f, Cint, (Cint,))
```

When using a clousure, you need to use `$` to interpolate the function into the macro,
and the second return value of `@cfunc` (`cf` in the example) should be referenced somewhere
to prevent the GC from collecting it.

## `Carray` and `@Carray`

`Carray` is similar to `StaticArrays.SArray`, representing a fixed-size immutable array.
Usually you only need to use `@Carray` whenever you need a C array. For example,

```c
int[3] a = {1,2,3};
struct bar {
    double x[2][4];
};
```

can be defined in Julia as:

```julia
a = @Carray(Cint[1,2,3])
struct Bar
    x::@Carray{Cdouble,2,4}
end
```

Note that the array will be stored in row-major order, so when you pass a Julia array to `@Carray`, the dimension order is reversed.

## `Cunion` and `@Cunion`

`Cunion` represents a C-style union. You need to use `@Cunion begin ... end` to declare a union type.
For example,

```c
union Baz {
    union {
        uint64_t x;
        unsigned char y[8];
    } a;
    uint b[2];
} baz = { .a = { .x = 0x123456789abcdef0 } };
```

should be:

```julia
const Baz = @Cunion begin
    a::@Cunion begin
        x::Cuint64
        y::@Carray{Cuchar,8}
    end
    b::Carray{Cuint,2}
end
baz = Baz(a=(; x=0x123456789abcdef0))
```

And the usage of `baz` is almost the same as in C, except that `Cunion`s and `Carray`s are all immutable.

## License

[MIT License](./LICENSE).
