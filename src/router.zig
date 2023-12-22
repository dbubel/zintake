const std = @import("std");

const Router = struct {
    const This = @This();
    r: std.AutoHashMap([]const u8, handlerFunc)
    // pub fn init() This {
    //     return .{};
    // }
};
