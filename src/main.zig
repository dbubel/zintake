const std = @import("std");
const router = @import("router.zig");
const handlers = @import("handler.zig");
pub fn main() !void {
    var server_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const server_allocator = server_gpa.allocator();
    const address = try std.net.Address.parseIp("0.0.0.0", 4000);
    var s = Server.init(address, server_allocator);
    try s.run(); // this block  s
}

const Server = struct {
    const This = @This();
    address: std.net.Address = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(addr: std.net.Address, alloc: std.mem.Allocator) This {
        return .{ .address = addr, .allocator = alloc };
    }

    pub fn run(self: *This) !void {
        var server = std.http.Server.init(self.allocator, .{ .kernel_backlog = 1024, .reuse_port = true, .reuse_address = true });
        defer server.deinit();

        const num_threads = 12; //try std.Thread.getCpuCount();
        const threads = try self.allocator.alloc(std.Thread, num_threads);

        try server.listen(self.address);

        for (threads) |*t| {
            t.* = try std.Thread.spawn(.{}, handler, .{&server});
        }

        for (threads) |t| {
            t.join();
        }
    }

    pub fn handler(server: *std.http.Server) !void {
        std.debug.print("thread started...\n", .{});
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const worker_allocator = gpa.allocator();
        var arena = std.heap.ArenaAllocator.init(worker_allocator);
        const allocator = arena.allocator();
        defer arena.deinit();

        while (true) {
            defer _ = arena.reset(.{ .retain_with_limit = 1024 * 1024 });
            var header_buf: [8192]u8 = undefined;

            var res = try server.accept(.{ .allocator = allocator, .header_strategy = .{ .static = &header_buf } });
            defer res.deinit();
            _ = res.wait() catch |err| {
                std.log.err("error in wait {any}", .{err});
                return;
            };

            var buf: [1024 * 1024]u8 = undefined;
            const n = res.readAll(&buf) catch |err| {
                std.log.err("read all err {any}", .{err});
                return;
            };
            _ = n;

            _ = res.send() catch |err| {
                std.log.err("error send {any}", .{err});
                return;
            };

            const a = "hello from server";
            res.transfer_encoding = .{ .content_length = a.len };
            _ = res.writeAll(a) catch |err| {
                std.log.err("error writeAll {any}", .{err});
                return;
            };

            _ = res.finish() catch |err| {
                std.log.err("error finish {any}", .{err});
                return;
            };
            _ = res.reset();
        }
    }
};
