# akane-embed

Compress and embed asset directories in your zig executables.

## Features

- Generates a zig module that mirrors the asset directory structure.
- Exposes each asset's byte range and the compressed and extracted sizes at comptime.
- Compresses all assets into one embedded data blob.
- Lets the application choose when to extract the bundle at runtime.

## Usage

```
zig fetch --save git+https://github.com/naipad/akane-embed
```

In your `build.zig`:

```zig
const akane_embed = @import("akane_embed");

pub fn build(b: *std.Build) !void {
    //...
    const my_bundle = akane_embed.create(b, b.path("assets"));
    exe.root_module.addImport("my_bundle", my_bundle);
}
```

In your code:

```zig
const std = @import("std");
const my_bundle = @import("my_bundle");

pub fn main(init: std.process.Init) !void {
    const data = try my_bundle.extract(init.arena.allocator());
    std.debug.print(
        \\A: '{s}'
        \\B: '{s}'
        \\C: '{s}'
        \\
        \\compressed: {}
        \\extracted:  {}
        \\
    , .{
        my_bundle.files.@"A.txt".get(data),
        my_bundle.files.@"B.txt".get(data),
        my_bundle.files.@"C.txt".get(data),
        my_bundle.size_compressed,
        my_bundle.size_extracted,
    });
}
```
