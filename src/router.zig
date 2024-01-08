const std = @import("std");
const endpoint = @import("endpoint.zig");

pub const Router = struct {
    const This = @This();
    routes: std.StringHashMap(endpoint.endpoint),
    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) This {
        const rs = std.StringHashMap(endpoint.endpoint).init(alloc);
        return .{ .routes = rs, .allocator = alloc };
    }

    pub fn addRoute(self: *This, h: endpoint.endpoint) !void {
        _ = 1;
        try self.routes.put("asdf", h);
        return;
    }
};

fn getme(_: *std.http.Server.Response) void {
    return;
}

test "test router" {
    const test_allocator = std.testing.allocator;
    const ep = endpoint.endpoint.new(endpoint.method.get, "/path", getme);
    var r = Router.init(test_allocator);
    try r.addRoute(ep);
    r.routes.deinit();
}
