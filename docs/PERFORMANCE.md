# Performance qualification

Updated: 2026-07-16

## Budgets

| Scenario | Candidate budget |
|---|---|
| Idle packaged app | under 1% CPU after the launch settles |
| Ordinary one/two-finger pointer use | no Swift raw-touch frames and no sustained CPU increase |
| Continuous volume gesture | immediate first accepted step; no repeated output-device discovery inside the 250 ms hot session |
| Window switcher launch | cached/icon-first overlay on the first main-thread turn; expensive thumbnails remain asynchronous |
| Window navigation | no window re-enumeration or thumbnail capture per movement frame |
| Native screenshot waiting | event-driven directory notification; no periodic polling wakeups |
| In-memory thumbnails | 32 MB maximum and deadline-driven eviction after 120 seconds without access |

Automated tests enforce a generous two-second ceiling for 50,000 combined input/navigation policy iterations and 10,000 cached Core Audio adjustments. These are regression tripwires, not substitutes for Instruments measurements on release hardware.

## Instruments procedure

1. Build the packaged release candidate and quit other profiling utilities.
2. Launch KeyFlow normally for an idle trace. Launch with `KEYFLOW_PERFORMANCE_SIGNPOSTS=1` only for scoped interaction traces.
3. Record Time Profiler, Points of Interest, Core Animation, and Allocations traces for idle, volume, screenshot, and switcher scenarios.
4. Attribute `screencapture`, WindowServer, and ScreenCaptureKit work separately from the KeyFlow process.
5. Record average/peak CPU, first-response latency, frame pacing, allocations, and retained memory in the audit report with hardware and macOS build.

Signposts are disabled by default and cover `AdjustVolume`, `ToggleMute`, `CaptureScreenshot`, `EnumerateWindows`, `ActivateWindow`, `BeginSwitcher`, `FinishSwitcher`, and `RefreshThumbnails`.
