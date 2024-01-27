const std = @import("std");
pub const r = @import("router.zig");

const person = struct {
    name: []const u8,
};

fn handleMe(conn: *std.http.Server.Response) void {
    var buf: [1024 * 1024]u8 = undefined;
    const n = conn.reader().readAll(&buf) catch |err| {
        std.log.err("read all err {any}", .{err});
        return;
    };
    _ = n;
    const p = person{
        .name = "dean",
    };

    var fbuf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&fbuf);
    _ = std.json.stringify(p, .{}, fbs.writer()) catch |err| {
        std.log.err("error stringify {any}", .{err});
        return;
    };

    conn.transfer_encoding = .{ .content_length = fbs.pos };

    _ = conn.writeAll(fbuf[0..fbs.pos]) catch |err| {
        std.log.err("error writeAll {any}", .{err});
        return;
    };
}

pub const Server = struct {
    const This = @This();
    address: std.net.Address = undefined,
    allocator: std.mem.Allocator = undefined,
    router: r.Router,

    pub fn init(addr: std.net.Address, alloc: std.mem.Allocator, router: r.Router) This {
        return .{ .address = addr, .allocator = alloc, .router = router };
    }

    pub fn run(self: *This) !void {
        var server = std.http.Server.init(self.allocator, .{ .kernel_backlog = 1024, .reuse_port = true, .reuse_address = true });
        defer server.deinit();

        const num_threads = 12; //try std.Thread.getCpuCount();
        const threads = try self.allocator.alloc(std.Thread, num_threads);

        try server.listen(self.address);

        for (threads) |*t| {
            t.* = try std.Thread.spawn(.{}, connectionHandler, .{&server});
        }

        for (threads) |t| {
            t.join();
        }
    }

    pub fn connectionHandler(server: *std.http.Server) !void {
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

            _ = res.send() catch |err| {
                std.log.err("error send {any}", .{err});
                return;
            };

            handleMe(&res);

            _ = res.finish() catch |err| {
                std.log.err("error finish {any}", .{err});
                return;
            };

            _ = res.reset();
        }
    }
};
