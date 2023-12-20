const std = @import("std");

pub fn main() !void {
    const c_alloc = std.heap.c_allocator;
    const address = try std.net.Address.parseIp("0.0.0.0", 4000);
    var s = Server.init(address, c_alloc);
    try s.run(); // this blocks
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

        var buf: [1024 * 1024]u8 = undefined;
        const n: usize = respCopy.readAll(&buf) catch |err| {
            std.log.err("error reading req body {any}", .{err});
            return;
        };
        std.debug.print("buf {any}\n", .{buf[0..n]});
        _ = respCopy.send() catch |err| {
            std.log.err("error send {any}", .{err});
            return;
        };
        const cl = resp.headers.getFirstValue("Content-Length");
        std.debug.print("content len {any}\n", .{cl});

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
            var header_buf: [1024 * 1024]u8 = undefined;
            const r = try self.allocator.create(std.http.Server.Response);
            r.* = try std.http.Server.accept(&server, .{ .allocator = self.allocator, .header_strategy = .{ .static = &header_buf } });

            std.debug.print("CL: {any}\n", .{r.headers.getFirstValue("Content-Length")});
r.headers
            thread_pool.spawn(handle, .{ self, r.* }) catch |err| {
                std.log.err("error spawning thread {any}", .{err});
            };
            self.allocator.destroy(r);
        }
    }
};
