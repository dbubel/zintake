const std = @import("std");
const z = @import("zintake");

pub fn main() !void {
    var server_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const server_allocator = server_gpa.allocator();
    const address = try std.net.Address.parseIp("0.0.0.0", 4000);
    const rout = z.r.Router.init(server_allocator);
    var s = z.Server.init(address, server_allocator, rout);
    try s.addRoute(z.ep.Endpoint.new(z.ep.method.get, "hello", handleMe));
    try s.run(); // this block
    // var thing = z.Thing.init();
    // thing.add(1, 1);
}
const person = struct {
    name: []const u8,
    addr: []const u8,
};
// fn getme(_: *std.http.Server.Response) void {
//     std.debug.print("in get me\n", .{});
//     return;
// }
fn handleMe(conn: *std.http.Server.Response) void {
    var buf: [1024 * 1024]u8 = undefined;
    const n = conn.reader().readAll(&buf) catch |err| {
        std.log.err("read all err {any}", .{err});
        return;
    };
    _ = n;
    const p = person{
        .name = "dean",
        .addr = "3591 hawfinch",
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
