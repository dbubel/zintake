const std = @import("std");
// const cores = @import("cores.zig");
// const cores = @cImport({
//     @cInclude("cores.h");
// });

pub fn main() !void {
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = alloc.allocator();
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();
    const address = try std.net.Address.parseIp("127.0.0.1", 4000);

    var s = Server.init(address, gpa);
    try s.run();
}

const Server = struct {
    const This = @This();
    address: std.net.Address = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(addr: std.net.Address, alloc: std.mem.Allocator) This {
        return .{ .address = addr, .allocator = alloc };
    }

    pub fn run(self: *This) !void {
        var server = std.http.Server.init(self.allocator, .{ .reuse_address = true });
        defer server.deinit();

        var thread_pool: std.Thread.Pool = undefined;
        defer thread_pool.deinit();

        try thread_pool.init(.{ .allocator = self.allocator, .n_jobs = 6 });
        try server.listen(self.address);
        var resp_pool = std.heap.MemoryPool(std.http.Server.Response).init(self.allocator);

        std.debug.print("waiting on connections...\n", .{});
        while (true) {
            const r = try resp_pool.create();
            // a.* = try std.http.Server.accept(&server, .{ .allocator = self.allocator });
            // const r = try self.allocator.create(std.http.Server.Response);
            r.* = try std.http.Server.accept(&server, .{ .allocator = self.allocator });
            thread_pool.spawn(handleConnection, .{r.*}) catch |err| {
                std.log.err("error spawning thread {any}", .{err});
            };
        }
    }
};

const handler = fn () void;

fn handleConnection(resp: std.http.Server.Response) void {
    var respCopy = resp; // this is very dumb i have to do this
    defer respCopy.deinit();
    _ = respCopy.wait() catch |err| {
        std.log.err("error wait {any}", .{err});
        return;
    };

    _ = respCopy.send() catch |err| {
        std.log.err("error send {any}", .{err});
        return;
    };

    const a = "hello from server";
    respCopy.transfer_encoding = .{ .content_length = a.len };
    _ = respCopy.writeAll(a) catch |err| {
        std.log.err("error writeAll {any}", .{err});
        return;
    };

    _ = respCopy.finish() catch |err| {
        std.log.err("error finish {any}", .{err});
        return;
    };
}
