# Loady

An ultra-lightweight native macOS menu bar system monitor.

> **Status: early development.** Nothing to install yet.

CPU, memory, disk, network, GPU and thermals, rendered live in the menu bar.
Universal binary — Intel and Apple Silicon, macOS 14 (Sonoma) and later.

## Why this exists

Mostly to learn how macOS actually reports this data: `host_processor_info`,
`host_statistics64`, the IORegistry, the SMC, and the undocumented corners
where Apple Silicon thermal data lives.

Every number is cross-checked against a first-party tool — Activity Monitor,
`powermetrics`, `vm_stat`, `netstat`, `ioreg` — before it ships. See
[`Docs/METRICS.md`](Docs/METRICS.md) for the formula and verification method
behind each one.

## License

MIT — see [LICENSE](LICENSE).
