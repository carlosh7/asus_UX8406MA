# Thermal Stress Test Results - UX8406MA

## Test Configuration
- **CPU**: Intel Core Ultra 9 185H (16 cores / 22 threads)
- **RAM**: 32GB LPDDR5x
- **Tool**: stress-ng (100% CPU load, 22 workers)
- **Duration**: 30 seconds per test
- **Cooldown**: 30 seconds between tests

---

## Results Summary

| Profile | Idle Temp | Stress Temp | Fan RPM | Throttling |
|---------|-----------|-------------|---------|------------|
| quiet | 64-91°C | 95-97°C | 2900-4900 | No |
| balanced | 65-76°C | 95-97°C | 3400-5100 | No |
| performance | 63-65°C | 99-101°C | 3600-7900 | **Yes** |

---

## Detailed Observations

### Quiet Profile
- **Idle**: Temperatures fluctuate (64-91°C) due to fan running at minimum speed
- **Stress**: Fan ramps from 3300 to 4900 RPM over 30 seconds
- **Behavior**: Allows CPU to get hot before increasing fan speed
- **Use case**: Silent operation, light tasks

### Balanced Profile
- **Idle**: Stable temperatures (65-76°C)
- **Stress**: Fan immediately at 4600-5100 RPM
- **Behavior**: Moderate fan response, good balance
- **Use case**: General use, moderate workloads

### Performance Profile
- **Idle**: Lowest temperatures (63-65°C)
- **Stress**: Fan ramps to maximum 7900 RPM
- **Behavior**: Maximum cooling, hits thermal throttle at 100°C+
- **Use case**: Heavy workloads, compilation, rendering

---

## Fan Behavior

| Profile | Idle RPM | Stress RPM | Ramp-up Time |
|---------|----------|------------|--------------|
| quiet | 2900 | 4900 | ~15s |
| balanced | 3400 | 5100 | ~5s |
| performance | 3600 | 7900 | ~10s |

**Key finding**: Fan response is slower in quiet profile (15s to reach 4900 RPM) vs balanced (5s to reach 5100 RPM).

---

## GPU Configuration

- **Driver**: xe (Intel Meteor Lake) + i915 fallback
- **FBC**: Auto (enabled)
- **PSR**: Auto (enabled)
- **PSR2**: Enabled
- **SAGV**: Enabled
- **IPS**: Enabled
- **GPU Temp**: Shared with CPU package (no separate sensor)

---

## Calibrated Thresholds (v4)

Based on real test data:

| Threshold | Value | Rationale |
|-----------|-------|-----------|
| quiet → balanced | 68°C | Light load begins |
| balanced → performance | 82°C | Heavy load, before throttle |
| hysteresis | 5°C | Prevent oscillation |
| dead band | 3°C | Avoid unnecessary changes |
| rate limit | 30s | Minimum time between changes |

---

## Recommendations

1. **For daily use**: Use `balanced` profile (best mix of noise and cooling)
2. **For silent work**: Use `quiet` profile (acceptable for light tasks)
3. **For heavy workloads**: Use `performance` profile (maximum cooling)
4. **Battery saving**: Quiet profile uses less fan power
5. **GPU**: Power saving features are enabled (good for battery)
