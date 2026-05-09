## Inventory Management Service Architecture

The inventory management service tracks real-time stock levels for 2 million SKUs across 800 warehouse locations. Reads heavily outnumber writes (read:write ratio approximately 50:1). The design proposes a microservice architecture deployed as 12 independently scalable services, each owning its bounded context (stock-level, reservation, fulfillment, replenishment, etc.), with eventual consistency maintained via Kafka event streaming between services.

### Consistency model

Stock reservation (triggered when a customer places an order) uses eventual consistency: the reservation service publishes a `stock.reserved` event to Kafka, and the stock-level service updates its local Postgres database asynchronously when it consumes the event. The window between event publish and stock-level update is typically under 500ms, but under load can extend to several seconds. Oversell protection is provided by a Redis counter per SKU that the reservation service decrements atomically before publishing the Kafka event; if the counter reaches zero, the reservation is rejected without writing to Kafka.

### Build vs. buy

The replenishment forecasting component (predicting when to reorder stock from suppliers) is proposed as a custom ML model trained on 5 years of sales history, retrained weekly. An alternative is to license a third-party demand-forecasting SaaS (e.g., Relex, Blue Yonder) at approximately $200k/year. The build option preserves flexibility and avoids vendor lock-in; the buy option provides faster time-to-value and shifts maintenance burden. The team has two ML engineers available.

### Service granularity

The 12-service split is proposed on the grounds of independent deployability and team autonomy. Each service is owned by a 2-engineer team. Critics within the team have argued that 12 services for a 24-engineer organization creates excessive operational overhead (12 deployment pipelines, 12 on-call rotations, cross-service distributed tracing required for every customer-facing operation). A monolith-first approach or a 3-service split (inventory-core, replenishment, reporting) is an alternative that several engineers have informally advocated.

### Caching strategy

Stock level reads are served from a Redis cluster (3-node, 16 GB per node). Cache TTL is 30 seconds; a write-through pattern is used so that every stock-level update writes to Redis before returning. Under write bursts (flash sales), the write-through pattern may serialize Redis writes with Postgres commits, increasing p99 write latency. An alternative is a write-behind cache with asynchronous Redis population, accepting a short window where the cache is stale.
