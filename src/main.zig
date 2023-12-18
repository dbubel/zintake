const std = @import("std");
// const cores = @import("cores.zig");
// const cores = @cImport({
//     @cInclude("cores.h");
// });

pub fn main() !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 4000);
    var s = Server.init(address);
    try s.run();
}

const Server = struct {
    const This = @This();
    address: std.net.Address = undefined,

    pub fn init(a: std.net.Address) This {
        return .{ .address = a };
    }

    pub fn run(self: *This) !void {
        var alloc = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa = alloc.allocator();

        var server = std.http.Server.init(gpa, .{ .reuse_address = true });
        defer server.deinit();

        var thread_pool: std.Thread.Pool = undefined;
        defer thread_pool.deinit();

        try thread_pool.init(.{ .allocator = gpa, .n_jobs = 12 });
        try server.listen(self.address);

        while (true) {
            var resp: std.http.Server.Response = try std.http.Server.accept(&server, .{ .allocator = gpa });
            thread_pool.spawn(handleConnection, .{&resp}) catch |err| {
                std.log.err("error spawning thread {any}", .{err});
            };
        }
    }
};

const handler = fn () void;

fn handleConnection(resp: *std.http.Server.Response) void {
    std.debug.print("in handle\n", .{});
    defer resp.deinit();
    _ = resp.wait() catch |err| {
        std.log.err("error wait {any}", .{err});
        return;
    };

    _ = resp.send() catch |err| {
        std.log.err("error send {any}", .{err});
        return;
    };

    const a = "hello from server";
    resp.transfer_encoding = .{ .content_length = a.len };
    _ = resp.writeAll(a) catch |err| {
        std.log.err("error writeAll {any}", .{err});
        return;
    };

    _ = resp.finish() catch |err| {
        std.log.err("error finish {any}", .{err});
        return;
    };
}
