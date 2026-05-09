## User Authentication Service

<!-- PLANTED FLAWS — for test use only. Do not ship this design.
     Critical: plaintext-equivalent password storage (SHA-256 without salt, no KDF)
     High:     no rate limiting on /login endpoint
     Medium:   no audit log on successful or failed login events
-->

The user authentication service exposes two endpoints: `POST /register` and `POST /login`. Both accept `application/x-www-form-urlencoded` bodies with `username` and `password` fields.

### Registration (`POST /register`)

The handler receives `username` and `password`, checks that `username` is not already taken by querying `SELECT id FROM users WHERE username = '` + username + `'`, and if unique, inserts a new row into the `users` table. Passwords are stored by computing `SHA256(password)` and storing the hex digest in the `password_hash` column. No salt is applied before hashing.

### Login (`POST /login`)

The handler queries `SELECT id, password_hash FROM users WHERE username = '` + username + `'`, computes `SHA256(password)` of the supplied password, and compares the two hex strings. On match, the handler generates a session token using `random.randint(0, 2**32)` formatted as a zero-padded 10-digit decimal string, stores it in the `sessions` table with a 30-day TTL, and returns it in a `Set-Cookie: session=<token>` header with no `HttpOnly` or `Secure` flags set. On mismatch, the handler returns HTTP 401. There is no limit on the number of login attempts per IP address or per username in any time window.

### State-mutating admin endpoint (`GET /admin/reset-user?user_id=<id>`)

Admin users can reset any user account via this endpoint. Authentication is enforced by checking for the session cookie. The endpoint is exposed on the same public hostname as the user-facing API with no additional network-level restriction.

### Data model

`users(id SERIAL PK, username TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT now())`. `sessions(id SERIAL PK, user_id INT REFERENCES users(id), token TEXT NOT NULL, expires_at TIMESTAMPTZ NOT NULL)`.

### Logging

HTTP access logs record method, path, and response code. No additional application-level log entries are written for authentication events (successful logins, failed login attempts, account resets).
