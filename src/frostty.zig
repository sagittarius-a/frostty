const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub const gtk_application_id = switch (builtin.mode) {
    .Debug, .ReleaseSafe => "com.mitchellh.ghostty.frostty-debug",
    .ReleaseFast, .ReleaseSmall => "com.mitchellh.ghostty.frostty",
};

pub const gtk_object_path = switch (builtin.mode) {
    .Debug, .ReleaseSafe => "/com/mitchellh/ghostty/frostty_debug",
    .ReleaseFast, .ReleaseSmall => "/com/mitchellh/ghostty/frostty",
};

pub fn isRuntime(alloc: Allocator) Allocator.Error!bool {
    const exe_path = std.fs.selfExePathAlloc(alloc) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer alloc.free(exe_path);

    if (comptime builtin.os.tag == .macos) {
        if (std.mem.indexOf(u8, exe_path, "/Frostty.app/") != null) return true;
    }

    return std.mem.eql(u8, std.fs.path.basename(exe_path), "frostty");
}
