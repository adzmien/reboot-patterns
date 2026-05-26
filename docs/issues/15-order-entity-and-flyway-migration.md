# Order Entity + Flyway V001__init.sql

## Spec Reference
ISSUE-2 from `docs/specs/spec-p2-resilience.md`

## What to build

Create the `Order` JPA entity and its Flyway migration. This establishes the data layer that `OrderService` will use to persist order placement attempts.

Deliverables:
- `src/main/resources/db/migration/V001__init.sql` — creates `p2_resilience.orders` table:
  ```sql
  CREATE TABLE orders (
    id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    item_id    VARCHAR(50)  NOT NULL,
    quantity   INT          NOT NULL,
    status     VARCHAR(20)  NOT NULL,  -- PENDING / ACCEPTED / FAILED
    created_at DATETIME     NOT NULL
  );
  ```
- `Order.java` — `@Entity`, fields match the table above; 1-line "why this exists" comment at the top of the class: `// Root aggregate for an order placement attempt; status tracks the payment outcome.`
- `OrderRepository.java` — `JpaRepository<Order, Long>`, no custom methods needed at this stage

## Acceptance Criteria

- [ ] On first boot, Flyway creates `p2_resilience.orders` without errors
- [ ] On second boot, Flyway detects no pending migrations and boots cleanly (idempotent)
- [ ] `Order` entity maps correctly (no Hibernate schema-validation errors on startup)

## Blocked by

- #14
