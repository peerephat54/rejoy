# ReJoy Backend

Node.js + Express + MongoDB Atlas backend for ReJoy.

## Setup

1. Copy `.env.example` to `.env`
2. Fill in `MONGODB_URI`
3. Optional: add `GEMINI_API_KEY` for full companion chat
4. Optional: set `CORS_ORIGIN` to your web app origin, or keep `*` while prototyping
5. Install dependencies:
   ```bash
   npm install
   ```
6. Start the server:
   ```bash
   npm run dev
   ```

## Mobile testing

For a real Android phone on the same Wi-Fi as your computer, run this backend
and build the Flutter app with the computer IP:

```bash
flutter build apk --debug --dart-define=REJOY_API_BASE_URL=http://YOUR_COMPUTER_IP:3000
```

The Flutter app also has a Profile > Backend / Cloud API card where you can
change the API URL on the phone without rebuilding the APK.

## Cloud deployment

Deploy this backend to Render/Railway/Fly.io so the phone no longer needs your
computer to stay on. For Render, this repo includes `render.yaml`.

Required cloud environment variables:

- `MONGODB_URI`
- `GEMINI_API_KEY` if using Gemini chat
- `CORS_ORIGIN` such as `*` during prototype, or your web origin later

After deployment, copy the cloud URL, for example:

```text
https://rejoy-backend.onrender.com
```

Then paste it into the mobile app in Profile > Backend / Cloud API and tap
`Test & Save`.

## Main endpoints

- `GET /api/health`
- `GET /api/users`
- `POST /api/users`
- `GET /api/quests`
- `POST /api/quests`
- `GET /api/reports`
- `POST /api/reports`
