# RK356x CPU performance mode

On the FS150 companion (`rk356x`, Ubuntu 20.04, four A55 cores) there is no
`nvpmodel`. For high-rate MAVROS / IMU / onboard control tests, set the CPU
governor to `performance` (all cores ~1800 MHz). This is runtime-only; it
resets on reboot unless you add a oneshot unit. Leave dmc/NPU/GPU/vdec
devfreq alone unless a specific test needs them.

```bash
for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
  [ -w "$f" ] || continue
  echo performance | sudo tee "$f" >/dev/null
done
```

Field observations and restore/thermal notes live in the engineering memory
vault `memory/field/fs150/rk356x-performance-mode.md` (GitHub `xgc2-dev-memory`).
