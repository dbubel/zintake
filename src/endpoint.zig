const std = @import("std");

pub const method = enum { get };

pub const endpoint = struct {
    const This = @This();

    verb: method,
    path: []const u8,

    handler: *const fn (*std.http.Server.Response) void,

    pub fn new(v: method, p: []const u8, h: *const fn (*std.http.Server.Response) void) This {
        return .{ .verb = v, .path = p, .handler = h };
    }
};

fn getme(_: *std.http.Server.Response) void {
    return;
}

test "handler new" {
    const handfn = getme;
    const ep = endpoint.new(method.get, "hello", handfn);
    _ = ep;
}
