# Zig Itertools

A toy iterator package for [zig](ziglang.org). Check the tests for examples.

This package is heavily based on rust's `std::iter` module.

## Usage

To use this package, use the zig package manager. For example in your build.zig.zon file, put:
```zig
.{
    .name = "app",
    .version = "0.1.0",
    .dependencies = .{
        .itertools = .{
            .url = "https://github.com/KilianVounckx/zitertools/archive/$COMMIT_YOU_WANT_TO_USE.tar.gz",
        },
    },
}
```

When running zig build now, zig will tell you you need a hash for the dependency and provide one.
Put it in you dependency so it looks like:
```zig
.{
  .itertools = .{
      .url = "https://github.com/KilianVounckx/zitertools/archive/$COMMIT_YOU_WANT_TO_USE.tar.gz",
      .hash = "$HASH_ZIG_GAVE_YOU",
  },
}
```

With the dependency in place, you can now put the following in your build.zig file:
```zig
    // This will create a `std.build.Dependency` which you can use to fetch
    // the itertools module. The first argument is the dependency name. It
    // should be the same as the one you used in build.zig.zon.
    const itertools = b.dependency("itertools", .{});
    // This will create a module which you can use in your zig code. The first
    // argument is the name you want your module to have in your zig code. It
    // can be anything you want. In your zig code you can use `@import` with
    // the same name to use it. The second argument is a module. You can
    // fetch it from the dependency with its `module` method. This method
    // takes one argument which is the name of the module. This time, the
    // name is the one the itertools package uses. It must be exactly the
    // same string as below: "itertools". The reason for needing this name is
    // that some packages can expose multiple modules. Therefor, you need to
    // specify which one you want. This package only exposes one module though,
    // so it will always be the same.
    exe.addModule("itertools", itertools.module("itertools"));
```

In the above change `exe` to whatever CompileStep you are using. For an executable it will
probably be exe, but `main_tests` or lib are also common.

With the build file in order, you can now use the module in your zig source. For example:

```zig
const std = @import("std");
// If you named the module something else in `build.zig`, use the other name here
// E.g. if in `build.zig` your did `exe.addModule("foobar", itertools.module("itertools"));`
// Then use `const itertools = @import("foobar");` here.
const itertools = @import("itertools");

pub fn main() void {
    var iter = itertools.range(u32, 0, 5);
    std.debug.print("{s}\n", .{ @typeName(itertools.Item(@TypeOf(iter))) }); // Output: u32
    std.debug.print("{?}\n", .{ iter.next()) }; // Output: 0
    std.debug.print("{?}\n", .{ iter.next()) }; // Output: 1
    std.debug.print("{?}\n", .{ iter.next()) }; // Output: 2
    std.debug.print("{?}\n", .{ iter.next()) }; // Output: 3
    std.debug.print("{?}\n", .{ iter.next()) }; // Output: 4
    std.debug.print("{?}\n", .{ iter.next()) }; // Output: null
}
```

Check the tests for more examples on how to use this package.
