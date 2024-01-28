const std = @import("std");
pub const r = @import("router.zig");
pub const ep = @import("endpoint.zig");
const person = struct {
    name: []const u8,
    addr: []const u8,
};

// fn handleMe(conn: *std.http.Server.Response) void {
//     var buf: [1024 * 1024]u8 = undefined;
//     const n = conn.reader().readAll(&buf) catch |err| {
//         std.log.err("read all err {any}", .{err});
//         return;
//     };
//     _ = n;
//     const p = person{
//         .name = "dean",
//         .addr = "3591 hawfinch",
//     };
//
//     var fbuf: [1024]u8 = undefined;
//     var fbs = std.io.fixedBufferStream(&fbuf);
//     _ = std.json.stringify(p, .{}, fbs.writer()) catch |err| {
//         std.log.err("error stringify {any}", .{err});
//         return;
//     };
//
//     conn.transfer_encoding = .{ .content_length = fbs.pos };
//
//     _ = conn.writeAll(fbuf[0..fbs.pos]) catch |err| {
//         std.log.err("error writeAll {any}", .{err});
//         return;
//     };
// }
// pub const Thing = struct {
//     const This = @This();
//     x: u32,
//     y: u32,
//     pub fn init() This {
//         return .{ .x = 1, .y = 1 };
//     }
//     pub fn add(self: *This, a: u32, b: u32) void {
//         self.x = a;
//         self.y = b;
//     }
// };
pub const Server = struct {
    const This = @This();
    address: std.net.Address = undefined,
    allocator: std.mem.Allocator = undefined,
    router: r.Router,

    // pub fn asdf(_: *This, a: u32, b: u32) void {
    //     std.debug.print("a + b\n", .{a + b});
    // }
    pub fn init(addr: std.net.Address, alloc: std.mem.Allocator, router: r.Router) This {
        // TODO:(dean) initialize the router here rahter that pass  a router in
        return .{ .address = addr, .allocator = alloc, .router = router };
    }

    pub fn addRoute(self: *This, e: ep.Endpoint) !void {
        try self.router.addRoute(e);
    }

    pub fn run(self: *This) !void {
        var server = std.http.Server.init(self.allocator, .{ .kernel_backlog = 1024, .reuse_port = true, .reuse_address = true });

        // var iter = self.router.routes.iterator();
        // while (iter.next()) |route| {
        //     std.debug.print("route: {s}\n", .{route.key_ptr.*});
        // }
        defer server.deinit();

        const num_threads = 12; //try std.Thread.getCpuCount();
        const threads = try self.allocator.alloc(std.Thread, num_threads);

        try server.listen(self.address);

        for (threads) |*t| {
            t.* = try std.Thread.spawn(.{}, connectionHandler, .{ self, &server });
        }

        for (threads) |t| {
            t.join();
        }
    }
    // TODO:(dean) this can be a pure function i think vs a method on this struct
    pub fn connectionHandler(self: *This, server: *std.http.Server) !void {
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

            // std.debug.print("path: {s}\n", .{res.request.target});
            const rr = self.router.routes.get(res.request.target);

            if (rr) |handler| {
                std.debug.print("calling hander {any} {s} \n", .{ handler.verb, handler.path });
                handler.handler(&res);
            } else {
                // not found hander here
                std.debug.print("no handler found\n", .{});
            }

            // handleMe(&res);

            _ = res.finish() catch |err| {
                std.log.err("error finish {any}", .{err});
                return;
            };

            _ = res.reset();
        }
    }
};
