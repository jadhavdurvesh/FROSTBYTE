const std = @import("std");
const RingBuffer = @import("ring_buffer.zig").RingBuffer;

/// Bounded outbound byte queue. The owner must serialize access to this value.
pub const WriteQueue = struct {
    ring: RingBuffer,

    pub fn init(storage: []u8) WriteQueue {
        return .{ .ring = RingBuffer.init(storage) };
    }

    /// Enqueue as many bytes as fit and return the accepted byte count.
    pub fn enqueue(self: *WriteQueue, bytes: []const u8) usize {
        return self.ring.write(bytes);
    }

    pub fn pending(self: *const WriteQueue) usize {
        return self.ring.len();
    }

    /// Attempt to write queued bytes. Partial writes are retained for the next
    /// call; callers should invoke this again when the socket is writable.
    pub fn flush(self: *WriteQueue, writer: anytype) !usize {
        var total: usize = 0;
        while (self.ring.len() > 0) {
            const chunk = self.ring.peekContiguous();
            const written = try writer.write(chunk);
            if (written == 0) return error.WriteZero;
            _ = self.ring.discard(written);
            total += written;
            if (written < chunk.len) break;
        }
        return total;
    }
};

test "outbound queue is bounded and retains byte order" {
    var storage: [8]u8 = undefined;
    var queue = WriteQueue.init(&storage);
    try std.testing.expectEqual(@as(usize, 6), queue.enqueue("abcdef"));
    try std.testing.expectEqual(@as(usize, 2), queue.enqueue("WXYZ"));
    try std.testing.expectEqual(@as(usize, 8), queue.pending());
    var output: [8]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 8), queue.ring.read(&output));
    try std.testing.expectEqualStrings("abcdefWX", &output);
}

test "outbound queue accepts more bytes after draining" {
    var storage: [5]u8 = undefined;
    var queue = WriteQueue.init(&storage);
    try std.testing.expectEqual(@as(usize, 5), queue.enqueue("12345"));
    var output: [3]u8 = undefined;
    _ = queue.ring.read(&output);
    try std.testing.expectEqual(@as(usize, 3), queue.enqueue("abc"));
    var remaining: [5]u8 = undefined;
    const count = queue.ring.read(&remaining);
    try std.testing.expectEqualStrings("45abc", remaining[0..count]);
}
