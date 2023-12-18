const std = @import("std");
// const cores = @import("cores.zig");
// const cores = @cImport({
//     @cInclude("cores.h");
// });

pub fn main() !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 4000);
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = alloc.allocator();
    // var s = Server.init(&gpa, address);
    var alloc2 = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa2 = alloc2.allocator();
    // try s.run();
    var server = std.http.Server.init(gpa, .{ .reuse_address = true });
    defer server.deinit();

    try server.listen(address);
    // std.log.info("server starting on {any} cores: {d}", .{ address, cores.num_cores() });

    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(.{ .allocator = gpa, .n_jobs = 12 });
    defer thread_pool.deinit();

    while (true) {
        std.debug.print("wait\n", .{});
        var resp: std.http.Server.Response = try std.http.Server.accept(&server, .{ .allocator = gpa2 });
        std.debug.print("conn rec\n", .{});
        thread_pool.spawn(handleConnection, .{&resp}) catch |err| {
            std.log.err("error spawning thread {any}", .{err});
        };
    }
}

const Server = struct {
    const This = @This();
    http_allocator: *std.mem.Allocator = undefined,
    // thread_allocator: *std.mem.Allocator = undefined,
    address: std.net.Address = undefined,

    pub fn init(ha: *std.mem.Allocator, a: std.net.Address) This {
        return .{
            .http_allocator = ha,
            // .thread_allocator = ta,
            .address = a,
        };
    }

    pub fn fuck(self: *This) void {
        _ = self;
        std.debug.print("in fuck\n", .{});
    }

    pub fn run(self: *This) !void {
        var thread_pool: std.Thread.Pool = undefined;
        try thread_pool.init(.{ .allocator = self.http_allocator.*, .n_jobs = 12 });
        defer thread_pool.deinit();

        var server = std.http.Server.init(self.http_allocator.*, .{ .reuse_address = true });
        defer server.deinit();
        try server.listen(self.address);
        std.debug.print("listneing...\n", .{});
        while (true) {
            std.debug.print("in loop\n", .{});

            const resp: std.http.Server.Response = try std.http.Server.accept(&server, .{ .allocator = self.http_allocator.* });
            _ = resp;
            std.debug.print("accepted new \n", .{});

            _ = thread_pool.spawn(fuck, .{self}) catch |err| {
                std.log.info("error spawning thread {any}\n", .{err});
            };
            std.debug.print("spawnd\n", .{});
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
