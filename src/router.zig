const std = @import("std");
const endpoint = @import("endpoint.zig");

pub const Router = struct {
    const This = @This();
    routes: std.StringHashMap(endpoint.Endpoint),
    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) This {
        const rs = std.StringHashMap(endpoint.Endpoint).init(alloc);
        return .{ .routes = rs, .allocator = alloc };
    }

    pub fn addRoute(self: *This, e: endpoint.Endpoint) !void {
        try self.routes.put("asdf", e);
        return;
    }
};

fn getme(_: *std.http.Server.Response) void {
    return;
}

test "test router" {
    const test_allocator = std.testing.allocator;
    var r = Router.init(test_allocator);
    const ep = endpoint.Endpoint.new(endpoint.method.get, "/hello", getme);
    try r.addRoute(ep);
    r.routes.deinit();
}
