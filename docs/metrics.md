# Metrics Measurement Methods

## 1) Latency & Jitter（时延/抖动）
- **Method**: Toggle a GPIO in ISR or at critical code points; capture with an oscilloscope/logic analyzer.
- **Notes**: Pin under test is dedicated; avoid extra bus activity.
- **Output**: Save PNG scope shots to `docs/img/latency.png` and `docs/img/jitter.png`.

## 2) Throughput（吞吐）
- **With lwIP**: TCP/UDP echo client/server;
- **Tools**: `iperf` or custom socket test.
- **Output**: Curate results into a CSV and plot later to `docs/img/throughput.png`.

## 3) Power（功耗）
- **Method**: Inline shunt + meter (or USB power meter); log V/I.
- **Output**: Aggregate into CSV; attach plot to `docs/img/power.png`.

## Baseline Template（基线模板）
- Record: test date, firmware commit, clock profile, cache/MPU state, RTOS on/off, PHY mode.
