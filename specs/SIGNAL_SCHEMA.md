# Signal Schema for Automated Reporting

## Purpose

Define a stable, cross-project schema for machine-readable signal output used by
`specs/AUTOMATED_REPORTING.md`.

This schema lives in the library (`specs/`) so projects can generate compatible
files in `docs/reports/signals/` without coupling to ad-hoc local formats.

## Output location in target projects

- `docs/reports/signals/SYSTEM_DIGEST_<YYYY-MM-DD>.json`

The path above is in the **target project**, not in this library repo.

## Top-level JSON shape

```json
{
  "version": "1.0",
  "generated_at": "2026-05-11T14:30:00Z",
  "mode": "baseline",
  "window": "7d",
  "since": null,
  "services": ["api", "web"],
  "summary": {
    "overall_status": "watch",
    "triggered_count": 3,
    "watch_count": 5,
    "unknown_count": 2
  },
  "signals": [],
  "recommendations": [],
  "unknowns": []
}
```

## Signal object

Each entry in `signals[]` must follow:

```json
{
  "signal_id": "rel-5xx-app-001",
  "category": "reliability",
  "service": "api",
  "metric": "http_5xx_rate",
  "unit": "percent",
  "current_value": 1.7,
  "baseline_value": 0.4,
  "delta": 1.3,
  "threshold": ">1.0 for 15m",
  "status": "triggered",
  "severity": "P1",
  "evidence_ref": "docs/reports/RESOURCE_CAPACITY_2026-05-11.md:72",
  "confidence": "high",
  "note": "spike aligns with edge timeout burst"
}
```

### Required fields

- `signal_id` (string, unique per report)
- `category` (`reliability|capacity|dependency|security|cost|drift`)
- `metric` (string)
- `current_value` (number or string if non-numeric)
- `threshold` (string)
- `status` (`ok|watch|triggered|unknown`)
- `evidence_ref` (string; file:line or telemetry source reference)
- `confidence` (`high|medium|low`)

### Optional fields

- `service` (string)
- `unit` (string)
- `baseline_value` (number/string/null)
- `delta` (number/string/null)
- `severity` (`P0|P1|P2|P3`)
- `note` (string)

## Recommendation object

Each entry in `recommendations[]` must reference one or more signal IDs.

```json
{
  "horizon": "immediate",
  "action": "Run /determinagents resource-capacity and prepare a human-approved edge scaling plan",
  "owner": "sre",
  "signal_refs": ["rel-5xx-app-001", "cap-cpu-edge-004"],
  "urgency": "high",
  "mutation_required": false,
  "approval_required": false
}
```

Required fields:

- `horizon` (`immediate|near-term|later`)
- `action` (string)
- `signal_refs` (non-empty string array)
- `urgency` (`high|medium|low`)

Recommended fields:

- `mutation_required` (boolean; default `false`)
- `approval_required` (boolean; `true` whenever `mutation_required=true`)

Recommendations may name mutating follow-up work, but the automated reporting
flow itself does not perform it. Prefer recommending the next determinagent
invocation first, then the human-approved operational change.

## Unknown object

Use `unknowns[]` to capture blocked conclusions.

```json
{
  "topic": "latency_baseline",
  "reason": "no stable prior window available",
  "needed_data": "7d p95 series from ingress and app service"
}
```

Required fields:

- `topic`
- `reason`
- `needed_data`

## Validation rules

1. `version` must be present and semver-like (`1.0`, `1.1`, etc.).
2. Every recommendation must reference existing `signal_id` values.
3. `status=triggered` should include `threshold` and non-empty `evidence_ref`.
4. If `confidence=low`, recommendation should prefer data collection over direct remediation.
5. If no triggers exist, leave `recommendations[]` empty and include an explicit
   no-action summary in the markdown report.

## Compatibility policy

- Additive changes (new optional fields) are backward compatible.
- Renames/removals require a version bump and migration note in
  `specs/AUTOMATED_REPORTING.md`.
