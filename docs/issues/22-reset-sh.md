# reset.sh for p2-resilience

## Spec Reference
ISSUE-9 from `docs/specs/spec-p2-resilience.md`

## What to build

Write `tests/p2-resilience/reset.sh`. Every `canonical-failure.sh` must source this as its first action. The script must be idempotent — safe to run at any time without breaking the cluster state.

Steps the script must perform (in order, each preceded by an `echo "Step N: ..."` line):
1. Drop and recreate the `p2_resilience` schema on MariaDB NodePort 30306.
2. Delete all WireMock stubs tagged `metadata.pattern: p2` via the WireMock admin API (`DELETE http://localhost:30080/__admin/mappings` filtered by metadata).
3. Print a confirmation that reset completed successfully.

Each step must `exit 1` with a descriptive message on failure.

## Acceptance Criteria

- [ ] Running `source ./tests/p2-resilience/reset.sh` twice in a row exits 0 both times
- [ ] After `reset.sh`, the `p2_resilience.orders` table is empty (or recreated clean)
- [ ] After `reset.sh`, `GET http://localhost:30080/__admin/mappings` returns no stubs tagged `pattern: p2`
- [ ] Script narrates each step with `echo "Step N: <action>"` before performing it

## Blocked by

- #18
