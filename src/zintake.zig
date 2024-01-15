const std = @import("std");
pub const r = @import("router.zig");
pub const e = @import("endpoint.zig");

pub const person = struct {
    name: []const u8,
    street: []const u8,
};

fn handleMe(conn: *std.http.Server.Response) void {
    var req_body: [1024 * 1024]u8 = undefined;
    const bytes_read = conn.reader().readAll(&req_body) catch |err| {
        std.log.err("read all err {any}", .{err});
        return;
    };
    _ = bytes_read;
    const p = person{
        .name = "dean",
        .street = "hawfinch",
    };

    var resp_buffer: [1024]u8 = undefined;
    var resp_buffer_stream = std.io.fixedBufferStream(&resp_buffer);
    _ = std.json.stringify(p, .{}, resp_buffer_stream.writer()) catch |err| {
        std.log.err("error stringify {any}", .{err});
        return;
    };

    conn.transfer_encoding = .{ .content_length = resp_buffer_stream.pos };
    _ = conn.writeAll(resp_buffer[0..resp_buffer_stream.pos]) catch |err| {
        std.log.err("error writeAll {any}", .{err});
        return;
    };
}

test "server" {
    var server_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const server_allocator = server_gpa.allocator();
    const address = try std.net.Address.parseIp("0.0.0.0", 4000);
    const rout = r.Router.init(server_allocator);
    var s = Server.init(address, server_allocator, rout);
    try s.router.addRoute(e.endpoint.new(e.method.get, "/route", handleMe));

    // var s:Server = Server.init(addr: std.net.Address, alloc: std.mem.Allocator, router: r.Router)
}
pub const Server = struct {
    const This = @This();
    address: std.net.Address = undefined,
    allocator: std.mem.Allocator = undefined,
    router: r.Router,

    pub fn init(addr: std.net.Address, alloc: std.mem.Allocator, ro: r.Router) This {
        return .{ .address = addr, .allocator = alloc, .router = ro };
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

            // std.debug.print("method: {any} path: {any"}", .{});
            _ = res.wait() catch |err| {
                std.log.err("error in wait {any}", .{err});
                return;
            };

            _ = res.send() catch |err| {
                std.log.err("error send {any}", .{err});
                return;
            };

            // use the router here
            handleMe(&res);

            // add 404 handler here

            _ = res.finish() catch |err| {
                std.log.err("error finish {any}", .{err});
                return;
            };

            std.debug.print("method: {any}\n", .{res.request});
            _ = res.reset();
        }
    }
};
