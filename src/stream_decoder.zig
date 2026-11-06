const std = @import("std");
const protocol = @import("protocol.zig");

/// Incremental decoder for arbitrary TCP chunks.
/// Returned payloads borrow decoder storage and remain valid until consumeFrame
/// or a subsequent feed/compaction operation.
pub const StreamDecoder = struct {
    storage: []u8,
    used: usize = 0,
    max_payload: usize,
    pending: usize = 0,

    pub fn init(storage: []u8, max_payload: usize) StreamDecoder {
        return .{ .storage = storage, .max_payload = @min(max_payload, protocol.DEFAULT_MAX_PAYLOAD) };
    }

    pub fn feed(self: *StreamDecoder, bytes: []const u8) error{FramePending, BufferFull}!usize {
        if (self.pending != 0) return error.FramePending;
        if (self.used == self.storage.len) return error.BufferFull;
        const count = @min(bytes.len, self.storage.len - self.used);
        @memcpy(self.storage[self.used .. self.used + count], bytes[0..count]);
        self.used += count;
        return count;
    }

    pub fn nextFrame(self: *StreamDecoder) protocol.ProtocolError!?protocol.Frame {
        if (self.pending != 0) return null;
        if (self.used < protocol.HEADER_LEN) return null;
        if (!std.mem.eql(u8, self.storage[0..4], &protocol.MAGIC)) return protocol.ProtocolError.InvalidMagic;
        if (self.storage[4] != protocol.VERSION) return protocol.ProtocolError.UnsupportedVersion;
        const payload_len = std.mem.readInt(u32, self.storage[8..12], .big);
        if (payload_len > self.max_payload) return protocol.ProtocolError.PayloadTooLarge;
        const total = protocol.HEADER_LEN + @as(usize, payload_len);
        if (self.used < total) return null;
        const frame = try protocol.decode(self.storage[0..total], self.max_payload);
        self.pending = total;
        return frame;
    }

    pub fn consumeFrame(self: *StreamDecoder) void {
        if (self.pending == 0) return;
        const remaining = self.used - self.pending;
        std.mem.copyForwards(u8, self.storage[0..remaining], self.storage[self.pending..self.used]);
        self.used = remaining;
        self.pending = 0;
    }

    pub fn buffered(self: *const StreamDecoder) usize { return self.used; }
};

test "incremental decoder accepts split header and payload" {
    const allocator = std.testing.allocator;
    const packet = try protocol.encode(allocator, 7, 1, "streaming");
    defer allocator.free(packet);
    var storage: [128]u8 = undefined;
    var decoder = StreamDecoder.init(&storage, 64);
    _ = try decoder.feed(packet[0..5]);
    try std.testing.expect((try decoder.nextFrame()) == null);
    _ = try decoder.feed(packet[5..19]);
    try std.testing.expect((try decoder.nextFrame()) == null);
    _ = try decoder.feed(packet[19..]);
    const frame = (try decoder.nextFrame()).?;
    try std.testing.expectEqual(@as(u16, 7), frame.header.message_type);
    try std.testing.expectEqualStrings("streaming", frame.payload);
    decoder.consumeFrame();
    try std.testing.expectEqual(@as(usize, 0), decoder.buffered());
}

test "incremental decoder separates coalesced packets" {
    const allocator = std.testing.allocator;
    const first = try protocol.encode(allocator, 1, 0, "one");
    defer allocator.free(first);
    const second = try protocol.encode(allocator, 2, 0, "two");
    defer allocator.free(second);
    var combined: [128]u8 = undefined;
    @memcpy(combined[0..first.len], first);
    @memcpy(combined[first.len .. first.len + second.len], second);
    var storage: [128]u8 = undefined;
    var decoder = StreamDecoder.init(&storage, 64);
    _ = try decoder.feed(combined[0 .. first.len + second.len]);
    const a = (try decoder.nextFrame()).?;
    try std.testing.expectEqualStrings("one", a.payload);
    decoder.consumeFrame();
    const b = (try decoder.nextFrame()).?;
    try std.testing.expectEqualStrings("two", b.payload);
    decoder.consumeFrame();
}
