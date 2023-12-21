const std = @import("std");

pub fn main() !void {
    var server_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const server_allocator = server_gpa.allocator();

    const c_alloc = std.heap.c_allocator;
    _ = c_alloc;
    const address = try std.net.Address.parseIp("0.0.0.0", 4000);
    var s = Server.init(address, server_allocator);
    try s.run2(); // this blocks
}

const Server = struct {
    const This = @This();
    address: std.net.Address = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(addr: std.net.Address, alloc: std.mem.Allocator) This {
        return .{ .address = addr, .allocator = alloc };
    }

    pub fn handle(_: *This, resp: std.http.Server.Response) void {
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

        const cl = respCopy.headers.getFirstValue("content-type");
        std.debug.print("content len {any}\n", .{cl});

        var buf: [1024 * 1024]u8 = undefined;
        const n: usize = respCopy.readAll(&buf) catch |err| {
            std.log.err("error reading req body {any}", .{err});
            return;
        };
        _ = n;

        // std.debug.print("buf {any}\n", .{buf[0..n]});

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

    pub fn run2(self: *This) !void {
        var server = std.http.Server.init(self.allocator, .{ .kernel_backlog = 1024, .reuse_port = true, .reuse_address = true });
        defer server.deinit();
        const num_threads = 1; //try std.Thread.getCpuCount();
        const threads = try self.allocator.alloc(std.Thread, num_threads);

        for (threads) |*t| {
            t.* = try std.Thread.spawn(.{}, handler2, .{&server});
        }

        for (threads) |t| {
            t.join();
        }
    }
    pub fn handler2(server: *std.http.Server) !void {
        // _ = server;
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const worker_allocator = gpa.allocator();
        //
        var arena = std.heap.ArenaAllocator.init(worker_allocator);
        defer arena.deinit();

        const allocator = arena.allocator();
        //
        // _ = allocator;
        while (true) {
            defer _ = arena.reset(.{ .retain_with_limit = 1024 * 1024 });
            var header_buf: [8192]u8 = undefined;
            const res = try server.accept(.{ .allocator = allocator, .header_strategy = .{ .static = &header_buf } });
            _ = res;
            // defer res.deinit();
            //
            // _ = res.wait() catch |err| {
            //     std.log.err("error in wait {any}", .{err});
            //     return;
            // };
            //
            // _ = res.send() catch |err| {
            //     std.log.err("error send {any}", .{err});
            //     return;
            // };
            //
            // _ = res.finish() catch |err| {
            //     std.log.err("error finish {any}", .{err});
            //     return;
            // };
            // _ = res.reset();
        }
    }
    pub fn run(self: *This) !void {
        var server = std.http.Server.init(self.allocator, .{ .kernel_backlog = 1024, .reuse_port = true, .reuse_address = true });
        defer server.deinit();

        var thread_pool: std.Thread.Pool = undefined;
        defer thread_pool.deinit();
        //std.Thread.getCpuCount()
        try thread_pool.init(.{ .allocator = self.allocator, .n_jobs = 12 });
        try server.listen(self.address);
        // var resp_pool = std.heap.MemoryPool(std.http.Server.Response).init(self.allocator);

        std.debug.print("\nwaiting on connections...\n", .{});
        while (true) {
            const r = try self.allocator.create(std.http.Server.Response);
            r.* = try std.http.Server.accept(&server, .{ .allocator = self.allocator });

            thread_pool.spawn(handle, .{ self, r.* }) catch |err| {
                std.log.err("error spawning thread {any}", .{err});
            };
            self.allocator.destroy(r);
        }
    }
};
