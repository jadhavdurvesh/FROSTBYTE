# FROSTBYTE roadmap

## M0 — Protocol core
- [x] Versioned binary frame header
- [x] Big-endian message type and payload length
- [x] Payload checksum
- [x] Zero-copy payload decoder
- [x] Configurable payload ceiling
- [x] Strict malformed/truncated packet rejection

## M1 — Buffering and transport
- [x] Fixed-capacity ring buffer
- [x] Wraparound-safe reads and writes
- [x] Framed TCP echo server
- [x] Protocol and ring-buffer unit tests
- [x] Incremental decoder for arbitrary TCP chunks
- [ ] Partial-write queue and backpressure policy
- [ ] Per-connection resource limits and idle timeout

## M2 — Performance engineering
- [ ] Allocator strategy benchmarks
- [ ] Throughput and latency benchmark harness
- [ ] Allocation-count instrumentation
- [ ] Fuzz testing and corpus regression
- [ ] SIMD checksum experiment with scalar fallback

## M3 — Production transport
- [ ] Multi-connection concurrency
- [ ] Cancellation and graceful shutdown
- [ ] TLS integration boundary
- [ ] Structured metrics and tracing
- [ ] Protocol compatibility and version negotiation tests

- [x] Incremental decoder feed reports partial acceptance and enforces bounded input buffering
- [x] Pending borrowed frames prevent further writes until consumed

- [x] Bounded outbound byte queue with partial-write retention and backpressure

- [x] Partial-write and zero-progress writer tests for outbound queue

- [x] Multi-connection TCP server using one detached worker thread per accepted client

The current threaded server has no global connection cap, graceful cancellation, idle timeout, or TLS. Keep it for local transport experiments, not untrusted production exposure.


- [ ] Add bounded concurrent connection admission, idle deadlines and graceful shutdown before exposing the server beyond local experiments
