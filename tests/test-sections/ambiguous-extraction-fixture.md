## Notification Dispatch Service

The notification dispatch service receives notification requests from upstream services via a Kafka topic (`notifications.v1`) and routes each message to the appropriate delivery channel: email (via SendGrid), SMS (via Twilio), or push (via FCM). A channel-selection lookup reads the user's preferences from a Postgres `notification_preferences` table, falling back to email if no preference is set. Each message is delivered at-least-once; the consumer commits its Kafka offset only after receiving a 2xx response from the downstream delivery API.

We should also consider a push-only fast path with these tradeoffs: skip the preferences lookup for push-eligible messages (those with `channel_hint: push` in the Kafka payload) and dispatch directly to FCM, bypassing Postgres entirely. This would reduce p99 latency by approximately 40ms at the cost of ignoring per-user preference overrides for users who have opted out of push. Whether the latency win justifies the preference-override risk is unresolved; the alternative is to maintain a hot Redis cache of push-opt-out flags keyed by user ID with a 5-minute TTL, which restores preference enforcement at ~2ms per lookup.

### Retry policy

Failed delivery attempts (non-2xx, network timeout) are retried up to 3 times with exponential backoff starting at 1 second (1s, 2s, 4s). After 3 failures, the message is written to a `failed_notifications` Postgres table for manual triage. No dead-letter Kafka topic is used.

### Throughput target

The service must handle 5,000 notification requests per second at p99 < 200ms end-to-end (from Kafka consume to delivery API response received).
