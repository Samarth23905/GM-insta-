# GMinsta

GMinsta is a full-stack Instagram-like application with:

- `GMinsta-backend/`: Node.js + Express + MongoDB + Socket.io API
- Flutter mobile/web client in this root project

## Backend Setup

1. Open `GMinsta-backend/`
2. Copy `.env.example` to `.env`
3. Install dependencies:

```bash
cd GMinsta-backend
npm install
```

4. Start MongoDB locally
5. Run the API:

```bash
npm run dev
```

API base URL: `http://localhost:5000/api`

## Flutter Setup

1. Install Flutter dependencies:

```bash
flutter pub get
```

2. Run the app against the backend:

```bash
flutter run --dart-define=GMINSTA_API_URL=http://localhost:5000/api
```

For Android emulators, use:

```bash
flutter run --dart-define=GMINSTA_API_URL=http://10.0.2.2:5000/api
```

## Sample API Requests

Register:

```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"demo\",\"email\":\"demo@example.com\",\"password\":\"secret123\",\"bio\":\"Hello from GMinsta\"}"
```

Login:

```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"demo@example.com\",\"password\":\"secret123\"}"
```

Feed:

```bash
curl http://localhost:5000/api/posts/feed \
  -H "Authorization: Bearer <jwt>"
```

Create post:

```bash
curl -X POST http://localhost:5000/api/posts \
  -H "Authorization: Bearer <jwt>" \
  -F "caption=My first GMinsta post" \
  -F "image=@sample.jpg"
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
