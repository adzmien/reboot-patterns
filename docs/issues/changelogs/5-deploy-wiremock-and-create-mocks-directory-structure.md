# Changelog — #5 Deploy WireMock and create mocks directory structure

**Branch:** `issue/5-deploy-wiremock-and-create-mocks-directory-structure`
**Date:** 2026-05-12
**Iterations used:** 1 of 5
**Status:** complete

## Proposed squash commit message

```text
feat(#5): deploy WireMock and create mocks directory structure

Add WireMock K8s Deployment (wiremock/wiremock:3.10.0) with
--global-response-templating enabled, and a NodePort Service exposing
port 30080. Create mocks/stubs/ directory with a README describing the
permanent cross-pattern stub convention (payment gateway, email gateway).

Acceptance criteria:
- [x] WireMock pod is Running after kubectl apply -f mocks/deployment/
- [x] curl -s http://100.66.8.44:30080/__admin/mappings returns HTTP 200 with an empty mappings array
- [x] A stub POSTed to /__admin/mappings with metadata.pattern: p1 is returned in the mappings list
- [x] DELETE /__admin/mappings filtered on that metadata successfully removes only that stub
- [x] mocks/stubs/README.md exists and describes the purpose of permanent cross-pattern stubs

Closes #5.
```

## Summary of changes

- Added `mocks/deployment/01-deployment.yaml`: WireMock Deployment using `wiremock/wiremock:3.10.0` with `--global-response-templating` arg, in `reboot-patterns` namespace.
- Added `mocks/deployment/02-service.yaml`: NodePort Service exposing WireMock on port 30080, following the same style as Redis and Kafka services in `infra/k8s/`.
- Added `mocks/stubs/README.md`: Describes the permanent cross-pattern stub convention, planned stub files, rules for `metadata.permanent: true`, and WireMock admin API quick reference.
- Updated `docs/issues/5-deploy-wiremock-and-create-mocks-directory-structure.md`: Marked all acceptance criteria as done, status updated to `done`.
- Updated `docs/issues/INDEX.md`: Status for #5 updated from `in-progress` to `done`.

## Acceptance criteria status

| # | Criterion | Status | Note |
|---|---|---|---|
| 1 | WireMock pod `Running` after `kubectl apply -f mocks/deployment/` | ✅ | `kubectl rollout status` confirmed successful rollout |
| 2 | `curl` to `/__admin/mappings` returns 200 with empty array | ✅ | Response: `{"mappings":[],"meta":{"total":0}}` |
| 3 | Stub POSTed with `metadata.pattern: p1` appears in GET | ✅ | Stub ID `8b06cd05-a982-4ce8-b9ee-30444dccae54` confirmed in listing |
| 4 | DELETE filtered by metadata removes only that stub | ✅ | Total mappings returned to 0 after DELETE |
| 5 | `mocks/stubs/README.md` exists and describes permanent stubs | ✅ | File created with full purpose, rules, and API reference |

## Files changed

### Added
- `mocks/deployment/01-deployment.yaml`
- `mocks/deployment/02-service.yaml`
- `mocks/stubs/README.md`

### Modified
- `docs/issues/5-deploy-wiremock-and-create-mocks-directory-structure.md`
- `docs/issues/INDEX.md`

### Deleted
None.

## Commits on branch

```
90e17d5 feat(#5): deploy WireMock and create mocks directory structure
caad8ec chore(#4): mark issue done
8284391 chore(#4): add changelog
0087b31 pattern(infra-redis): adapt and deploy Redis to reboot-patterns
```

(The first three commits above belong to issue #4 and were already present on this branch before #5 work began.)

## Verification

- ✅ `kubectl apply -f mocks/deployment/` — applied cleanly, both resources created
- ✅ WireMock pod Running — `kubectl rollout status deployment/wiremock -n reboot-patterns` confirmed
- ✅ `curl http://100.66.8.44:30080/__admin/mappings` returns 200 — `{"mappings":[],"meta":{"total":0}}`
- ✅ Stub POST + GET + DELETE round-trip verified — stub created, appeared in list, deleted by metadata filter
- N/A `./gradlew build` — no Java code in this issue

## Outstanding follow-ups

None.
