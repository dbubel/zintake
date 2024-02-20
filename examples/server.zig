const std = @import("std");
const zintake = @import("zintake");
const methods = std.http.Method;

pub fn main() !void {
    var server_gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const server_allocator = server_gpa.allocator();
    const address = try std.net.Address.parseIp("0.0.0.0", 4000);
    const rout = zintake.r.Router.init(server_allocator);

    var s = zintake.Server.init(address, server_allocator, rout);
    // want to see something very stupid, change this to const below
    var endpointGroup = [_]zintake.endpoint.Endpoint{
        zintake.endpoint.Endpoint.new(methods.GET, "/hello", handleMe),
        zintake.endpoint.Endpoint.new(methods.GET, "/api/hello", handleMe),
    };
    try s.addRoutes(endpointGroup[0..]);
    try s.run(); // this block
}

const person = struct {
    name: []const u8,
    addr: []const u8,
};

const payload: person = person{
    .name = "dean",
    .addr = "3591 hawfinch",
};

var handleAlloc = std.heap.GeneralPurposeAllocator(.{}){};
const handleAl = handleAlloc.allocator();
const worker_allocator = handleAl.allocator();
var arena = std.heap.ArenaAllocator.init(worker_allocator);
const allocator = arena.allocator();
// defer arena.deinit();

fn handleMe(conn: *std.http.Server.Response) void {
    defer conn.finish() catch |err| {
        std.log.err("error finish{any}", .{err});
    };

    // read the request made
    var buf: [1024 * 1024]u8 = undefined;
    const n: usize = conn.reader().readAll(&buf) catch |err| {
        std.log.err("read all err {any}", .{err});
        return;
    };
    // _ = n; // length of the request

    const p = std.json.parseFromSlice(person, handleAl, buf[0..n], .{}) catch |err| {
        conn.status = .bad_request;
        conn.transfer_encoding = .{ .content_length = 0 };

        conn.send() catch |erra| {
            std.log.err("error send {any}", .{erra});
        };
        std.log.err("json parse {any}", .{err});
        return;
    };
    defer p.deinit();
    std.debug.print("P: {any}\n", .{p.value});

    // make a buffer and then wrap it in a stream so we can we can print out json
    // response into it
    var fbuf: [1024]u8 = undefined;
    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(&fbuf);

    std.json.stringify(p.value, .{}, fbs.writer()) catch |err| {
        std.log.err("error stringify {any}", .{err});
        return;
    };

    conn.status = .ok;
    conn.transfer_encoding = .{ .content_length = fbs.pos };

    conn.send() catch |erra| {
        std.log.err("error send {any}", .{erra});
    };
    conn.writeAll(fbuf[0..fbs.pos]) catch |err| {
        std.log.err("error writeAll {any}", .{err});
        return;
    };
    // conn.transfer_encoding = .chunked;
    // try res.send();
    // try res.writeAll("Hello, World!\n");
    // try res.finish();
}
