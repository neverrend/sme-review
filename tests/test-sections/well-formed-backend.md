## Order Ingestion Service

The order ingestion service receives POST requests at `/orders` from the storefront frontend and mobile clients. Each request body contains a JSON payload with `customer_id`, `line_items` (array of `{sku, quantity, unit_price_cents}`), and an optional `idempotency_key` (UUID v4). The service validates the payload against a JSON Schema, then writes the order to a Postgres 15 `orders` table inside a serializable transaction. The `idempotency_key` column has a unique index; on conflict, the existing order row is returned with HTTP 200 rather than inserting a duplicate.

### Data flow

1. HTTP handler validates the request body (400 on schema failure).
2. Handler looks up `idempotency_key` in a Redis cache (TTL 24 hours) before hitting Postgres; cache hit returns the cached order ID immediately.
3. On cache miss, handler opens a Postgres transaction: inserts into `orders`, inserts line items into `order_line_items`, and publishes an `order.created` event to a Kafka topic (`orders.v1`) within the same logical step using the transactional outbox pattern (a `pending_events` table drained by a background poller every 500ms).
4. On successful commit, the handler caches `{idempotency_key → order_id}` in Redis with the 24-hour TTL, then returns HTTP 201 with the new `order_id`.

### Persistence

- **Postgres schema:** `orders(id UUID PK, customer_id UUID NOT NULL, created_at TIMESTAMPTZ DEFAULT now(), status TEXT NOT NULL DEFAULT 'pending', idempotency_key UUID UNIQUE)`. `order_line_items(id UUID PK, order_id UUID FK REFERENCES orders(id) ON DELETE CASCADE, sku TEXT NOT NULL, quantity INT NOT NULL CHECK (quantity > 0), unit_price_cents INT NOT NULL CHECK (unit_price_cents >= 0))`.
- **Indexes:** `orders(idempotency_key)` unique, `order_line_items(order_id)` btree.
- **Kafka topic:** `orders.v1` with 12 partitions, retention 7 days, keyed on `customer_id` for ordering per customer.

### Failure modes considered

- Postgres write fails after Redis cache check: the transaction rolls back; the handler returns 500; the client retries with the same idempotency key and hits the Postgres unique constraint on the next attempt, which returns 409 — handled by looking up and returning the existing row.
- Outbox poller crashes mid-drain: events remain in `pending_events`; the next poll cycle picks them up. At-least-once delivery to Kafka is guaranteed; consumers must deduplicate on `order_id`.
- Redis unavailable: the service falls back to Postgres for idempotency checks (no cache layer), accepting higher latency.
