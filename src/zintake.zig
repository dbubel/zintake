const std = @import("std");
const log = @import("std").log;
pub const r = @import("router.zig");
pub const endpoint = @import("endpoint.zig");

pub const Server = struct {
    const red = "\x1b[31m";
    const green = "\x1b[32m";
    const reset = "\x1b[0m";
    const red_bg = "\x1b[41m";
    const green_bg = "\x1b[42m";
    const dark_red_bg = "\x1b[48;5;52m";
    const This = @This();
    address: std.net.Address = undefined,
    allocator: std.mem.Allocator = undefined, // TODO:(dean) might not need to have allocator here
    router: r.Router,

    pub fn init(addr: std.net.Address, alloc: std.mem.Allocator, router: r.Router) This {
        // TODO:(dean) initialize the router here rahter that pass  a router in
        return .{ .address = addr, .allocator = alloc, .router = router };
    }

    pub fn addRoute(self: *This, e: endpoint.Endpoint) !void {
        log.info("added route {s}{any}{s} {s}", .{ green_bg, e.verb, reset, e.path });
        try self.router.addRoute(e);
    }
    pub fn addRoutes(self: *This, endpoints: []endpoint.Endpoint) !void {
        for (endpoints) |e| {
            try self.addRoute(e);
        }
    }

    pub fn run(self: *This) !void {
        var server = std.http.Server.init(.{ .kernel_backlog = 1024, .reuse_port = true, .reuse_address = true });

        defer server.deinit();

        const num_threads = 12; //try std.Thread.getCpuCount();
        const threads = try self.allocator.alloc(std.Thread, num_threads);

        try server.listen(self.address);

        for (threads) |*t| {
            t.* = try std.Thread.spawn(.{}, handlerThread, .{ &self.router, &server });
        }

        for (threads) |t| {
            t.join();
        }
    }
};

// This runs in its own thread handing connections
pub fn handlerThread(router: *r.Router, server: *std.http.Server) !void {
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
        const rr = router.routes.get(res.request.target);

        if (rr) |handler| {
            // std.debug.print("calling hander {any} {s} \n", .{ handler.verb, handler.path });
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
