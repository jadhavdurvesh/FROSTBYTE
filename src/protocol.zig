const std = @import("std");
pub const MAGIC = [_]u8{ 'F', 'R', 'S', 'T' };
pub const VERSION: u8 = 1;
pub const HEADER_LEN: usize = 16;
pub const DEFAULT_MAX_PAYLOAD: usize = 1024 * 1024;
pub const ProtocolError = error{ InvalidMagic, UnsupportedVersion, PayloadTooLarge, TruncatedFrame, ChecksumMismatch };

pub const Header = struct { version: u8 = VERSION, flags: u8 = 0, message_type: u16 = 0, payload_len: u32 = 0, checksum: u32 = 0 };
/// Decoded frames borrow their payload from the input packet.
pub const Frame = struct { header: Header, payload: []const u8 };

pub fn checksum(bytes: []const u8) u32 {
    var hash: u32 = 2166136261;
    for (bytes) |byte| hash = (hash ^ byte) *% 16777619;
    return hash;
}

pub fn encode(allocator: std.mem.Allocator, message_type: u16, flags: u8, payload: []const u8) ![]u8 {
    if (payload.len > DEFAULT_MAX_PAYLOAD or payload.len > std.math.maxInt(u32)) return ProtocolError.PayloadTooLarge;
    const output = try allocator.alloc(u8, HEADER_LEN + payload.len);
    @memcpy(output[0..4], &MAGIC);
    output[4] = VERSION;
    output[5] = flags;
    std.mem.writeInt(u16, output[6..8], message_type, .big);
    std.mem.writeInt(u32, output[8..12], @intCast(payload.len), .big);
    std.mem.writeInt(u32, output[12..16], checksum(payload), .big);
    @memcpy(output[HEADER_LEN..], payload);
    return output;
}

/// Parse one complete packet; the returned payload aliases input.
pub fn decode(input: []const u8, max_payload: usize) ProtocolError!Frame {
    if (input.len < HEADER_LEN) return ProtocolError.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..4], &MAGIC)) return ProtocolError.InvalidMagic;
    if (input[4] != VERSION) return ProtocolError.UnsupportedVersion;
    const payload_len = std.mem.readInt(u32, input[8..12], .big);
    if (payload_len > max_payload or payload_len > DEFAULT_MAX_PAYLOAD) return ProtocolError.PayloadTooLarge;
    const total_len = HEADER_LEN + @as(usize, payload_len);
    if (input.len != total_len) return ProtocolError.TruncatedFrame;
    const payload = input[HEADER_LEN..total_len];
    const expected = std.mem.readInt(u32, input[12..16], .big);
    if (checksum(payload) != expected) return ProtocolError.ChecksumMismatch;
    return .{ .header = .{ .version = input[4], .flags = input[5], .message_type = std.mem.readInt(u16, input[6..8], .big), .payload_len = payload_len, .checksum = expected }, .payload = payload };
}

test "round trip preserves header and borrowed payload" {
    const allocator = std.testing.allocator;
    const bytes = try encode(allocator, 0x102, 0xA0, "zero-copy payload");
    defer allocator.free(bytes);
    const frame = try decode(bytes, DEFAULT_MAX_PAYLOAD);
    try std.testing.expectEqual(@as(u16, 0x102), frame.header.message_type);
    try std.testing.expectEqual(@as(u8, 0xA0), frame.header.flags);
    try std.testing.expectEqualStrings("zero-copy payload", frame.payload);
    try std.testing.expect(frame.payload.ptr == bytes[HEADER_LEN..].ptr);
}

test "rejects malformed and truncated frames" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(ProtocolError.TruncatedFrame, decode("short", DEFAULT_MAX_PAYLOAD));
    const bytes = try encode(allocator, 1, 0, "hello");
    defer allocator.free(bytes);
    var corrupted = try allocator.dupe(u8, bytes);
    defer allocator.free(corrupted);
    corrupted[0] = 'X';
    try std.testing.expectError(ProtocolError.InvalidMagic, decode(corrupted, DEFAULT_MAX_PAYLOAD));
    corrupted[0] = 'F';
    corrupted[HEADER_LEN] ^= 0x01;
    try std.testing.expectError(ProtocolError.ChecksumMismatch, decode(corrupted, DEFAULT_MAX_PAYLOAD));
}

test "enforces payload ceiling and exact packet length" {
    const allocator = std.testing.allocator;
    const bytes = try encode(allocator, 1, 0, "123456");
    defer allocator.free(bytes);
    try std.testing.expectError(ProtocolError.PayloadTooLarge, decode(bytes, 5));
    try std.testing.expectError(ProtocolError.TruncatedFrame, decode(bytes[0 .. bytes.len - 1], 32));
}
