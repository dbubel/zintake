const std = @import("std");

const middlewareFunc = fn (*const fn (u32) void, u32) void;

fn firstMiddleware(next: *const fn (u32) void, data: u32) void {
    std.debug.print("First middleware with data: {}\n", .{data});
    next(data);
}

fn secondMiddleware(next: *const fn (u32) void, data: u32) void {
    std.debug.print("Second middleware with data: {}\n", .{data});
    next(data);
}

fn finalFunction(data: u32) void {
    std.debug.print("Final function with data: {}\n", .{data});
}

pub fn main() void {
    const chain = [_]*const middlewareFunc{ &firstMiddleware, &secondMiddleware };
    for (chain) |func| {
        std.debug.print("func {any}\n", .{func});
    }
}
