const std = @import("std");
const handler = *const fn (u32) void;

const middlewareFunc = fn (handler) handler;

fn firstMiddleware(h: handler) handler {
    _ = h;
    return fn (u32) void{};
}
//
// fn secondMiddleware(next: *const fn (u32) void) void {
//     std.debug.print("Second middleware with data: \n", .{});
//     next(1);
// }
//
// fn finalFunction(data: u32) void {
//     std.debug.print("Final function with data: {}\n", .{data});
// }

pub fn main() void {
    const j: middlewareFunc = firstMiddleware;
    _ = j;
    // firstMiddleware(x(2));
    // const chain = [_]*const middlewareFunc{ &firstMiddleware, &secondMiddleware };
    // for (chain) |func| {
    //     std.debug.print("func {any}\n", .{func});
    // }
}
