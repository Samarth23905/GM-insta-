# GMinsta Backend

Production-ready Express, MongoDB, and Socket.io backend for the GMinsta social app.

## Features

- JWT authentication with bcrypt password hashing
- Posts with multer uploads, likes, and dislikes
- Popup-ready comments API
- Story uploads with 24-hour expiry using MongoDB TTL
- Follow requests with accept and reject flows
- Case-insensitive user search
- Mutual-follower-only chat with REST and Socket.io delivery

## Setup

1. Copy `.env.example` to `.env`
2. Install dependencies:

```bash
npm install
```

3. Start MongoDB locally or update `MONGO_URI`
4. Run the server:

```bash
npm run dev
```

The API runs on `http://localhost:5000` by default.

## Key Routes

### Authentication

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `GET /api/auth/search?q=john`
- `GET /api/auth/users/:userId`

### Posts and Stories

- `POST /api/posts` with multipart field `image`
- `GET /api/posts/feed`
- `PUT /api/posts/:postId/react` with `{ "reaction": "like" }`
- `GET /api/posts/user/:userId`
- `POST /api/posts/stories` with multipart field `media`
- `GET /api/posts/stories/active`

### Comments

- `POST /api/comments/:postId`
- `GET /api/comments/:postId`

### Follows

- `POST /api/follow/request/:userId`
- `POST /api/follow/respond/:requesterId`
- `GET /api/follow/requests`

### Chat

- `GET /api/chat/mutuals`
- `POST /api/chat/messages/:receiverId`
- `GET /api/chat/messages/:receiverId`

## Sample Request

```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"demo\",\"email\":\"demo@example.com\",\"password\":\"secret123\"}"
```

## Socket.io

Connect with a JWT token:

```js
const socket = io("http://localhost:5000", {
  auth: {
    token: "<jwt>"
  }
});
```

Listen for new messages with `message:new`.
