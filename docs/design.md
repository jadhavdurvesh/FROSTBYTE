# FROSTBYTE design notes

## Scope

FROSTBYTE is a protocol-engineering laboratory focused on explicit ownership and predictable memory behavior. The first milestone intentionally uses a small protocol and a single-threaded TCP server so parser correctness can be evaluated independently of concurrency.

## Decoder invariants

1. Header size is fixed at 16 bytes.
2. Magic and version are checked before interpreting payload content.
3. Payload length is checked against both the caller's ceiling and the hard protocol maximum.
4. A frame must contain exactly one packet; trailing bytes are rejected.
5. Payload checksum is verified before exposing the borrowed slice.
6. Decoding performs no heap allocation and does not copy payload bytes.

## Buffer invariants

- 0 <= used <= capacity
- head and tail always remain within supplied storage when capacity is non-zero.
- Writes never overwrite unread bytes.
- Reads never expose bytes beyond the current used range.
- A zero-capacity buffer safely accepts no data.

## TCP framing

TCP is a byte stream, not a message transport. The server first reads the fixed header, validates the declared payload length against the hard ceiling, then reads exactly the payload length. The parser validates the complete packet before it is echoed.

The current server handles accepted connections sequentially. It is suitable for protocol experiments and local testing, not high-concurrency production traffic.

## Integrity is not authentication

The FNV-1a checksum detects accidental corruption in the payload. It is not cryptographic and does not protect against malicious modification. Authentication and confidentiality belong at a TLS or authenticated transport layer.

## Memory lifetime

A decoded frame's payload borrows from the input packet. Callers must not retain it after freeing or mutating the packet. Encoded packets are allocator-owned and must be released by the caller.

## Future design questions

- The incremental decoder supports fragmented headers and payloads in caller-supplied bounded storage; future work should benchmark compaction and throughput.
- Backpressure should bound queued outbound bytes per connection.
- Multi-connection concurrency should define ownership and cancellation rules before introducing shared mutable state.
- Benchmarks must report compiler version, optimization mode, hardware, payload sizes, and methodology. No performance claim should be published without reproducible measurements.

## Incremental stream decoder and backpressure

The incremental decoder accepts arbitrary input chunks into caller-supplied fixed-capacity storage. `feed` returns the exact number of bytes accepted; callers must retain and retry any unaccepted suffix. When the buffer is full it returns `BufferFull`, and while a borrowed frame is pending it returns `FramePending` to prevent invalidating the borrowed payload. This is bounded inbound buffering, not an outbound socket write queue.
