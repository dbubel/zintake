const std = @import("std");
const endpoint = @import("endpoint.zig");

pub const Router = struct {
    const This = @This();
    routes: std.StringHashMap(*const fn (*std.http.Server.Response) void),
    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) This {
        const rs = std.StringHashMap(*const fn (*std.http.Server.Response) void).init(alloc);
        return .{ .routes = rs, .allocator = alloc };
    }

    pub fn addRoute(self: *This, f: *const fn (*std.http.Server.Response) void) !void {
        try self.routes.put("asdf", f);
        return;
    }
};

fn getme(_: *std.http.Server.Response) void {
    return;
}

test "test router" {
    const test_allocator = std.testing.allocator;
    var r = Router.init(test_allocator);
    try r.addRoute(getme);
    r.routes.deinit();
}
