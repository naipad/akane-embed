const std = @import("std");

pub const Loc = struct {
    start: usize,
    end: usize,

    pub fn size(loc: Loc) usize {
        return loc.end - loc.start;
    }

    pub fn bytes(loc: Loc, extracted_data: []const u8) []const u8 {
        return extracted_data[loc.start..loc.end];
    }

    pub fn get(loc: Loc, extracted_data: [:0]u8) [:0]u8 {
        return extracted_data[loc.start..loc.end :0];
    }
};

pub const Limits = struct {
    max_extracted_size: usize = 256 * 1024 * 1024,
};

pub fn validateExtractedSize(size: usize, limits: Limits) !void {
    if (size > limits.max_extracted_size) return error.ExtractedSizeLimitExceeded;
}

test "Loc exposes binary-safe bytes" {
    const data: [:0]u8 = @constCast("a\x00b\x00");
    const loc = Loc{ .start = 0, .end = 3 };
    try std.testing.expectEqualSlices(u8, "a\x00b", loc.bytes(data));
}

test "extracted size limit rejects oversized bundles" {
    try std.testing.expectError(error.ExtractedSizeLimitExceeded, validateExtractedSize(11, .{ .max_extracted_size = 10 }));
    try validateExtractedSize(10, .{ .max_extracted_size = 10 });
}
