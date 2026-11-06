const std = @import("std");
/// Fixed-capacity byte ring. Push and pop are O(1); callers own synchronization.
pub const RingBuffer = struct {
    storage: []u8, head: usize = 0, tail: usize = 0, used: usize = 0,
    pub fn init(storage: []u8) RingBuffer { return .{ .storage = storage }; }
    pub fn len(self: *const RingBuffer) usize { return self.used; }
    pub fn capacity(self: *const RingBuffer) usize { return self.storage.len; }
    pub fn free(self: *const RingBuffer) usize { return self.storage.len - self.used; }
    pub fn write(self: *RingBuffer, input: []const u8) usize {
        const count = @min(input.len, self.free());
        if (count == 0 or self.storage.len == 0) return 0;
        const first = @min(count, self.storage.len - self.tail);
        @memcpy(self.storage[self.tail .. self.tail + first], input[0..first]);
        const second = count - first;
        if (second > 0) @memcpy(self.storage[0..second], input[first .. first + second]);
        self.tail = (self.tail + count) % self.storage.len;
        self.used += count;
        return count;
    }
    pub fn read(self: *RingBuffer, output: []u8) usize {
        const count = @min(output.len, self.used);
        if (count == 0 or self.storage.len == 0) return 0;
        const first = @min(count, self.storage.len - self.head);
        @memcpy(output[0..first], self.storage[self.head .. self.head + first]);
        const second = count - first;
        if (second > 0) @memcpy(output[first .. first + second], self.storage[0..second]);
        self.head = (self.head + count) % self.storage.len;
        self.used -= count;
        return count;
    }
    pub fn peekContiguous(self: *const RingBuffer) []const u8 {
        if (self.used == 0) return self.storage[0..0];
        return self.storage[self.head .. self.head + @min(self.used, self.storage.len - self.head)];
    }
    pub fn discard(self: *RingBuffer, count: usize) usize {
        const actual = @min(count, self.used);
        if (self.storage.len == 0) return 0;
        self.head = (self.head + actual) % self.storage.len;
        self.used -= actual;
        return actual;
    }
};

test "wraps around without changing byte order" {
    var storage: [8]u8 = undefined;
    var ring = RingBuffer.init(&storage);
    try std.testing.expectEqual(@as(usize, 6), ring.write("abcdef"));
    var first: [4]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 4), ring.read(&first));
    try std.testing.expectEqualStrings("abcd", &first);
    try std.testing.expectEqual(@as(usize, 6), ring.write("ghijkl"));
    var output: [8]u8 = undefined;
    const count = ring.read(&output);
    try std.testing.expectEqual(@as(usize, 8), count);
    try std.testing.expectEqualStrings("efghijkl", output[0..count]);
}

test "does not overwrite unread bytes when full" {
    var storage: [4]u8 = undefined;
    var ring = RingBuffer.init(&storage);
    try std.testing.expectEqual(@as(usize, 4), ring.write("abcd"));
    try std.testing.expectEqual(@as(usize, 0), ring.write("x"));
    try std.testing.expectEqual(@as(usize, 4), ring.len());
    try std.testing.expectEqual(@as(usize, 4), ring.discard(99));
    try std.testing.expectEqual(@as(usize, 0), ring.len());
}
