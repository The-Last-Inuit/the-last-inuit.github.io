+++
title = "phenomena | Update"
date = 2026-01-16
+++

We add supports local actor types
`Person`, `Application`, and `Service`, along with `Note`, `Article`, and `Image`
objects and basic activity types (`Create`, `Update`, `Delete`, `Follow`, `Undo`,
`Like`, `Announce`).

**ActivityPub endpoints**

- `POST /oauth/token`
- `GET /.well-known/webfinger`
- `GET /.well-known/nodeinfo`
- `GET /nodeinfo/2.0`
- `GET /users/:username`
- `GET /users/:username/outbox`
- `POST /users/:username/outbox`
- `POST /users/:username/media`
- `POST /users/:username/inbox`
- `POST /inbox`
- `GET /users/:username/followers`
- `GET /users/:username/following`
- `GET /objects/:id`
- `GET /activities/:id`

**C2S example**

```bash
curl -X POST http://localhost:4000/users/alice/outbox \
  -H "content-type: application/activity+json" \
  -H "authorization: Bearer ACCESS_TOKEN" \
  -d '{"type":"Note","content":"Hello ActivityPub!", \
     "to":["https://www.w3.org/ns/activitystreams#Public"]}'
```

**Outbox image upload**

```bash
curl -X POST http://localhost:4000/users/alice/outbox \
  -H "authorization: Bearer ACCESS_TOKEN" \
  -F "file=@/path/to/image.png" \
  -F "to=https://www.w3.org/ns/activitystreams#Public"
```

**Media upload example**

```bash
curl -X POST http://localhost:4000/users/alice/media \
  -H "authorization: Bearer ACCESS_TOKEN" \
  -F "file=@/path/to/image.png"
```

Use the returned `url` and `mediaType` when creating an `Image` object in the outbox.

**Collection pagination**

Outbox, followers, and following collections return an `OrderedCollection` 
with `first` and `last` links by default. Add `?page=1` (or `?page=true`) to 
receive an `OrderedCollectionPage` response.
