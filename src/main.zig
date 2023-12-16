const std = @import("std");
const cores = @import("cores.zig");
// const cores = @cImport({
//     @cInclude("cores.h");
// });

pub fn main() !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 8080);
    var gpa_server = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_server.allocator();
    var server = std.http.Server.init(gpa, .{ .reuse_address = true });
    defer server.deinit();

    try server.listen(address);
    std.log.info("server starting on {any} cores: {d}", .{ address, cores.num_cores() });

    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(.{ .allocator = gpa, .n_jobs = @intCast(cores.num_cores()) });
    defer thread_pool.deinit();

    while (true) {
        var resp: std.http.Server.Response = try std.http.Server.accept(&server, .{ .allocator = gpa });
        thread_pool.spawn(handleConnection, .{&resp}) catch |err| {
            std.log.err("error spawning thread {any}", .{err});
        };
    }
}
const Server = struct {
    const This = @This();
    const http_allocator: std.mem.Allocator = undefined;
    const thread_allocator: std.mem.Allocator = undefined;
    const address: std.net.Address = undefined;

    pub fn init(ha: *std.mem.Allocator, ta: *std.mem.Allocator, a: std.net.Address) This {
        return .{
            .http_allocator = ha,
            .thread_allocator = ta,
            .address = a,
        };
    }
};

const handler = fn () void;

fn handleConnection(resp: *std.http.Server.Response) void {
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
