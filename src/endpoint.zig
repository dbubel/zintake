const std = @import("std");

pub const method = enum { get };

pub const Endpoint = struct {
    const This = @This();

    verb: method,
    path: []const u8,
    handler: *const fn (*std.http.Server.Response) void,
    // middleware: linked_list,
    pub fn new(v: method, p: []const u8, h: *const fn (*std.http.Server.Response) void) This {
        return .{ .verb = v, .path = p, .handler = h };
    }
};

pub const Node = struct {
    value: *const fn (*std.http.Server.Response) void,
    next: ?*Node,
};
pub const linked_list = struct {
    allocator: *std.mem.Allocator,
    head: ?*Node,

    pub fn init(allocator: *std.mem.Allocator) linked_list {
        return linked_list{ .head = null, .allocator = allocator, .len = 0 };
    }

    pub fn push(self: *linked_list, value: i32) !void {
        const new_node: *Node = try self.allocator.create(Node);
        new_node.* = Node{ .value = value, .next = self.head };
        self.head = new_node;
    }

    pub fn pop(self: *linked_list) ?i32 {
        if (self.head) |head| {
            self.head = head.next;
            const x = head.value;
            self.allocator.destroy(head);
            return x;
        }
        return null;
    }

    pub fn print(self: *linked_list) void {
        var current_node: ?*Node = self.head;
        while (current_node) |i| {
            std.debug.print("{d}\n", .{i.value});
            current_node = i.next;
        }
    }
};
