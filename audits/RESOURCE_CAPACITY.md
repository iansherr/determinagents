# Resource Capacity Audit

## Purpose

Find capacity and resource-pressure risks before they become incidents: CPU saturation, memory pressure, storage and network bottlenecks, dependency contention (DB/queue/cache), and missing guardrails such as limits, autoscaling, and disruption controls.

This is a **runtime-agnostic** audit. It first detects the deployment model (Kubernetes, Docker/Compose, bare metal/systemd, Unraid, or mixed), then applies runtime-specific collection commands while keeping a common severity model and report shape.

Read-only by default. This audit does not generate load or mutate infrastructure.

## When to run

Before traffic ramps, after capacity-related incidents, before major feature launches, and quarterly for preventive maintenance.


**Model tier**: `reasoning`

## Time estimate

Depends on runtime complexity and telemetry availability. Use `--phases=N,M` or `--max-time=Xm` to scope.

## Output

`docs/reports/RESOURCE_CAPACITY_<YYYY-MM-DD>.md`.

---

## Phase 0: Discovery (runtime + telemetry)

Identify deployment runtime and available observability sources.

```bash
# Runtime hints
ls -la .kube kubeconfig* 2>/dev/null
find . -maxdepth 3 -type f \( -name 'docker-compose*.yml' -o -name 'compose*.yml' -o -name 'Dockerfile*' \) 2>/dev/null
find . -maxdepth 4 -type f \( -name '*.service' -o -name 'supervisord*.conf' \) 2>/dev/null
find . -maxdepth 4 -type f \( -name '*unraid*' -o -name '*community-applications*' \) 2>/dev/null

# Infra manifests / configs
find . -maxdepth 5 -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.tf' \) \
  | grep -E '(k8s|kubernetes|helm|compose|docker|ingress|service|deployment|statefulset|hpa|vpa|pdb|autoscal)' \
  | head -100

# Telemetry & runbooks
find . -maxdepth 5 -type f \( -name '*runbook*' -o -name '*observab*' -o -name '*dashboard*' -o -name '*alerts*' \) 2>/dev/null
grep -rEn --include='*.md' --include='*.yaml' --include='*.yml' \
  -E '(prometheus|grafana|loki|datadog|new relic|cloudwatch|stackdriver|otel|opentelemetry)' . | head -100
```

Record:
- Runtime(s) detected
- Critical services and data stores
- Primary telemetry/log sources available in this repo or referenced by runbooks

---

## Phase 1: Guardrails inventory

Goal: detect missing baseline controls that make capacity failures likely.

### 1.1 Kubernetes guardrails (if k8s present)

```bash
grep -rEn --include='*.yaml' --include='*.yml' \
  -E '(kind:\s*Deployment|kind:\s*StatefulSet|resources:|requests:|limits:|HorizontalPodAutoscaler|VerticalPodAutoscaler|PodDisruptionBudget)' \
  . | head -200
```

Flag examples:
- Workloads with no CPU/memory requests and limits
- No HPA/VPA/PDB on critical services

### 1.2 Docker/Compose guardrails (if docker/compose present)

```bash
grep -rEn --include='docker-compose*.yml' --include='compose*.yml' \
  -E '(mem_limit|cpus|cpu_shares|restart:|ulimits|healthcheck:)' . | head -200
```

Flag examples:
- Services with no memory/CPU ceilings
- Missing healthchecks and restart policies

### 1.3 Bare-metal/systemd guardrails (if systemd/process managers present)

```bash
grep -rEn --include='*.service' --include='*.conf' \
  -E '(MemoryMax|CPUQuota|TasksMax|LimitNOFILE|Restart=|TimeoutStartSec|TimeoutStopSec)' . | head -200
```

Flag examples:
- Critical processes with no restart/limits
- File descriptor limits too low for expected concurrency

### 1.4 Unraid / mixed-host guardrails (if detected)

```bash
grep -rEn --include='*.md' --include='*.yaml' --include='*.yml' \
  -E '(unraid|cache pool|array|parity|docker memory|vm memory|cpu pinning)' . | head -200
```

Flag examples:
- No stated resource ceilings for containers/VMs
- No runbook constraints around array/parity/rebuild capacity impact

---

## Phase 2: Pressure indicators from logs and configs

Goal: find evidence of active or recurring resource strain.

```bash
grep -rEn --include='*.log' --include='*.txt' --include='*.md' --include='*.json' \
  -E '(OOMKilled|OutOfMemory|Evicted|CrashLoopBackOff|throttl|CPU pressure|MemoryPressure|DiskPressure|NetworkUnavailable|connection pool exhausted|too many open files|timeout|i/o timeout|502|503|504)' \
  . | head -300
```

If repo logs are sparse, use runbook references and alert definitions as evidence sources.

Record:
- Signal type
- Affected service/component
- Frequency (single occurrence vs recurring pattern)

---

## Phase 3: Dependency capacity checks (DB/queue/cache/LB)

Goal: identify non-app bottlenecks that surface as app instability.

```bash
grep -rEn --include='*.env' --include='*.yaml' --include='*.yml' --include='*.toml' --include='*.ini' \
  -E '(pool|max_connections|connection_limit|redis|maxclients|queue|broker|prefetch|worker_concurrency|nginx.*worker|keepalive|rate limit|backoff|retry)' \
  . | head -250
```

Flag examples:
- DB connection pool and app concurrency clearly mismatched
- Retry policies without jitter/backoff under failure
- LB/proxy worker settings inconsistent with target throughput

---

## Phase 4: Runtime-specific deep checks

Choose the matching branch from discovery.

### 4A Kubernetes

- Compare requests/limits against observed pressure indicators.
- Check autoscaling target metrics align to real bottleneck (CPU-only HPA when memory/OOM is dominant = likely mismatch).
- Identify single-replica critical services lacking disruption tolerance.

### 4B Docker/Compose

- Check host-level contention indicators and whether container limits prevent noisy-neighbor failures.
- Check restart storms and healthcheck flapping as capacity symptoms.

### 4C Bare metal/systemd

- Check process-level limits, swap behavior, and I/O timeout evidence.
- Verify service restart/backoff policy can recover without cascading overload.

### 4D Unraid/mixed home-lab

- Check contention between containers/VMs and storage array/cache operations.
- Check whether operational events (parity checks/rebuilds) are accounted for in runbooks and capacity expectations.

---

## Phase 5: Synthesis and right-sized actions

For each top finding, propose the smallest corrective action likely to reduce risk.

Examples:
- Add missing requests/limits on critical workload
- Adjust pool size + app concurrency in tandem
- Add/retune HPA trigger to match bottleneck signal
- Add PDB for critical multi-replica service
- Add runbook guardrail for known high-pressure maintenance windows

Each finding must include file:line evidence and a concrete suggested fix.

---

## Severity rubric (this audit)

- **P0**: Active capacity failure risk with immediate outage/data-loss potential (repeated OOMKills on critical path, hard saturation, recurring 5xx from dependency exhaustion) with no effective guardrail.
- **P1**: High likelihood of incident under expected growth/spikes (missing limits/autoscaling/disruption controls on critical services, or clearly mismatched dependency capacity settings).
- **P2**: Suboptimal configuration that increases toil/cost or degrades resilience but is not imminently incident-causing.
- **P3**: Observations and hygiene improvements (documentation gaps, weak but non-critical defaults).

---

## Report template

```markdown
# Resource Capacity Audit — <YYYY-MM-DD>

## Summary
<2-4 sentences: runtime detected, top pressure themes, highest risk area>

## Runtime profile
- **Detected runtime(s)**: <k8s | docker | bare metal | unraid | mixed>
- **Critical services**: <list>
- **Primary dependencies**: <DB, cache, queue, LB>
- **Telemetry sources used**: <logs, configs, runbooks, dashboards refs>

## Findings

| Severity | Category | Location | Evidence | Suggested fix |
|---|---|---|---|---|
| P1 | Memory pressure | `deploy/k8s/api.yaml:42` | No memory limits + repeated OOMKilled in runbook incident note | Add memory request/limit and tune rollout guardrails |

## Top risks by surface
- **Compute**: ...
- **Memory**: ...
- **Storage**: ...
- **Network**: ...
- **Dependencies**: ...

## Capacity actions (prioritized)
1. ...
2. ...
3. ...

## Next steps
- Re-run this audit after applying top 1-3 changes.
- If high-risk findings remain uncertain, run a verification harness in a disposable environment.
```
