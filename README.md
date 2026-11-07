# FROSTBYTE

**A zero-copy binary protocol and network framing engine written in Zig.**

FROSTBYTE explores bounded binary parsing, explicit memory ownership, fixed-capacity buffering, and TCP stream framing. It contains a versioned wire format, zero-copy frame decoder, byte ring buffer, and framed TCP echo server.

## Core capabilities

- Versioned binary frame format with a fixed 16-byte header
- Big-endian fields and explicit payload length
- FNV-1a payload integrity checksum
- Zero-copy payload views from decoded packets
- Configurable maximum payload limit (1 MiB default)
- Fixed-capacity ring buffer with wraparound-safe reads and writes
- Incremental decoder for split and coalesced TCP frames
- Bounded outbound write queue with partial-write retention and explicit backpressure
- TCP server that reads complete frames from a byte stream
- Zig unit tests and GitHub Actions CI

## Wire format v1

| Offset | Size | Field | Description |
|---:|---:|---|---|
| 0 | 4 | Magic | ASCII FRST |
| 4 | 1 | Version | Currently 1 |
| 5 | 1 | Flags | Application-defined flags |
| 6 | 2 | Message type | Unsigned big-endian |
| 8 | 4 | Payload length | Unsigned big-endian |
| 12 | 4 | Checksum | FNV-1a 32-bit payload checksum |
| 16 | N | Payload | Opaque application bytes |

A packet is exactly 16 + payload_length bytes. The decoder rejects unknown versions, invalid magic, oversized payloads, truncated or overlong packets, and checksum mismatches.

## Memory ownership

decode does not allocate or copy payload bytes. The returned Frame.payload is a borrowed slice into the input packet. The caller must keep the input packet alive and unchanged while using that view.

encode allocates a packet owned by the caller. The caller must free the returned slice with the allocator used to create it.

The ring buffer owns no memory: callers provide its storage. It is intentionally not internally synchronized.

## Requirements

- Zig 0.13.0

## Build and test

    zig fmt src build.zig
    zig build test
    zig build

Run the TCP echo server on port 9000:

    zig build run

Or specify a port:

    zig build run -- 9100

The server accepts FROSTBYTE v1 frames and echoes the same message type, flags, and payload. It is a development protocol server, not an internet-hardened production service.

## Project layout

    src/
      frostbyte.zig       Public module surface
      protocol.zig        Wire format, encoder, decoder, tests
      ring_buffer.zig     Fixed-capacity byte ring and tests
      main.zig            TCP framed echo server
    build.zig             Build, test, and run steps

See ROADMAP.md and docs/design.md.

## License

MIT.

The outbound queue's tests cover bounded capacity, partial writes, retained byte order, and zero-progress writer handling. The caller remains responsible for socket readiness and serialized access.
