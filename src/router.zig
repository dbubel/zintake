const std = @import("std");
const handlers = @import("endpoint.zig");

pub const Router = struct {
    const This = @This();
    routes: std.StringHashMap(*handlers.handlerFunc),
    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) This {
        const rs = std.StringHashMap(*handlers.handlerFunc).init(alloc);
        return .{ .routes = rs, .allocator = alloc };
    }

    pub fn addRoute(self: *This) void {
        self.routes.put("asdf", getme);
        return;
    }
};

fn getme(req: *std.http.Server.Request, res: *std.http.Server.Response) void {
    _ = req;
    _ = res;
    return;
}

test "test router" {
    const test_allocator = std.testing.allocator;
    const r = Router.init(test_allocator);
    _ = r;
}
