const std = @import("std");

pub const handlerFunc = fn (req: *std.http.Server.Request, res: *std.http.Server.Response) void;

const endpoints = []endpoint;

const method = enum { get };

const endpoint = struct {
    const This = @This();

    verb: method,
    path: []const u8,
    handler: handlerFunc,

    pub fn new(comptime v: method, comptime handlerFn: handlerFunc) This {
        return .{ .verb = v, .path = "path", .handler = handlerFn };
    }
};

fn getme(req: *std.http.Server.Request, res: *std.http.Server.Response) void {
    _ = req;
    _ = res;
    return;
}

test "handler new" {
    const handfn = getme;
    const ep = endpoint.new(method.get, handfn);
    _ = ep;
}
