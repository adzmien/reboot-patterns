# Deploy WireMock and create mocks directory structure
Status: done 2026-05-12

## Spec Reference

ISSUE-5 from `docs/specs/spec-curriculum-setup.md`

## What to build

Write WireMock K8s manifests in `mocks/deployment/` (Deployment: `wiremock/wiremock:3.10.0` with `--global-response-templating`, Service: NodePort 30080). Create `mocks/stubs/` directory with a `README.md` explaining it holds permanent cross-pattern stubs (payment gateway, email gateway) that are loaded at WireMock boot. No stub JSON files yet — those are added per-pattern.

## Acceptance Criteria

- [x] WireMock pod is `Running` after `kubectl apply -f mocks/deployment/`
- [x] `curl -s http://100.66.8.44:30080/__admin/mappings` returns HTTP 200 with an empty mappings array
- [x] A stub POSTed to `/__admin/mappings` with `metadata.pattern: p1` is returned in the mappings list
- [x] `DELETE /__admin/mappings` filtered on that metadata successfully removes only that stub
- [x] `mocks/stubs/README.md` exists and describes the purpose of permanent cross-pattern stubs

## Blocked by

None — can start immediately
