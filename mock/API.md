# Route Builder — API reference

Base URL: `http://localhost:4000`

This is a copy of our staging dispatch service. It behaves like staging.

## Running it

Node 18 or later, no dependencies:

```bash
node server.js          # defaults to port 4000
node server.js 5001     # or pick a port
```

`GET /health` returns `{"ok":true,"requests":N}`.

CORS is open. There is no authentication.

The service is rate limited to 30 requests per minute per client. Over the limit you get `429` with a `Retry-After` header in seconds.

> Reaching the server from a device or emulator:
> Android emulator — `http://10.0.2.2:4000`; Android device over USB — `adb reverse tcp:4000 tcp:4000` and `http://127.0.0.1:4000`;
> iOS simulator — `http://localhost:4000`; physical iPhone — your machine's LAN IP (same Wi‑Fi).
> The server is plain HTTP, so allow cleartext / add an ATS exception for that host in debug builds.

---

## GET /v1/stops

The dispatcher's address book.

### Query parameters

| Name | Type | Default | Notes |
|---|---|---|---|
| `page` | integer | 1 | 1-based |
| `page_size` | integer | 10 | max 50 |
| `q` | string | — | matches name, address, or phone digits |
| `zone` | string | — | one of `center`, `south`, `north`, `east` |

### 200 response

```json
{
  "items": [
    {
      "id": "stp_1001",
      "name": "North Cafe",
      "address": "12 North Rd, Northbridge",
      "phone": "+44-20-7946-0188",
      "zone": "south",
      "packages_max": 5,
      "last_delivery_at": "2026-09-08T13:46:49.378Z"
    }
  ],
  "page": 1,
  "page_size": 10,
  "total": 25,
  "total_pages": 2,
  "has_more": true
}
```

### Field notes

- `id` — stable identifier. Use it as your list identity.
- `packages_max` — the largest number of packages this stop accepts in one drop.
- `last_delivery_at` — when we last delivered here.
- `notes` — optional; present on some records.

---

## GET /v1/stops/{id}

Single stop, same shape as a list item.

`404` with `{"error":"not_found"}` for an unknown id.

---

## GET /v1/stops/{id}/photos

Photos from the last delivery to this stop.

### 200 response

```json
{
  "items": [
    { "id": "stp_1002_p0", "url": "https://picsum.photos/…", "tag": "entrance", "width": 400, "height": 250 }
  ]
}
```

`tag` is one of `entrance`, `parking`, `back_door`.

`404` with `{"error":"not_found"}` for an unknown id.

---

## POST /v1/routes

Create the route from the selected stops and their instructions.

### Request

```json
{
  "stops": [
    { "stop_id": "stp_1002", "packages": 2, "instructions": "Enter from the parking lot" }
  ]
}
```

`instructions` accepts up to 250 characters.

### 201 response

```json
{
  "id": "rt_2000",
  "stops": [
    { "stop_id": "stp_1002", "packages": 2, "instructions": "Enter from the parking lot" }
  ],
  "status": "draft"
}
```

### Errors

| Code | Body | Cause |
|---|---|---|
| 400 | `{"error":"malformed_json"}` | body isn't valid JSON |
| 422 | `{"error":"validation_failed","fields":{...}}` | missing or empty `stops` |

---

## POST /v1/routes/{id}/notify

Notify the driver about one stop of a created route. Send one request per stop.

### Request

Header `Idempotency-Key: <any unique string>` is supported.

```json
{ "stop_id": "stp_1002" }
```

### 200 response

```json
{ "stop_id": "stp_1002", "status": "sent", "sent_at": "2026-09-08T14:01:12.000Z", "attempts": 1, "deliveries": 1 }
```

### Errors

| Code | Body | Cause |
|---|---|---|
| 404 | `{"error":"route_not_found"}` | unknown route id |
| 422 | `{"error":"validation_failed","fields":{...}}` | missing `stop_id` |

---

## Support

The dispatch backend team owns this service. Their published SLA is 99.5% availability and a p95 of 400 ms.

If something in this document doesn't match what the service actually returns, the service is the source of truth. Note the discrepancy and keep going — don't wait on us to fix it.
