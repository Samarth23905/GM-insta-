const fs = require("fs");
const http = require("http");
const path = require("path");
const cors = require("cors");
const dotenv = require("dotenv");
const express = require("express");
const connectDB = require("./config/db");
const authRoutes = require("./routes/authRoutes");
const postRoutes = require("./routes/postRoutes");
const commentRoutes = require("./routes/commentRoutes");
const chatRoutes = require("./routes/chatRoutes");
const followRoutes = require("./routes/followRoutes");
const { initSocket } = require("./utils/socket");

dotenv.config();

const app = express();

[
  path.join(__dirname, "uploads"),
  path.join(__dirname, "uploads", "posts"),
  path.join(__dirname, "uploads", "stories"),
  path.join(__dirname, "uploads", "profiles")
].forEach((directory) => {
  if (!fs.existsSync(directory)) {
    fs.mkdirSync(directory, { recursive: true });
  }
});

app.use(
  cors({
    origin: (origin, callback) => {
      return callback(null, true);
    },
    credentials: true
  })
);
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    service: "GMinsta backend"
  });
});

app.use("/api/auth", authRoutes);
app.use("/api/posts", postRoutes);
app.use("/api/comments", commentRoutes);
app.use("/api/chat", chatRoutes);
app.use("/api/follow", followRoutes);

app.use((req, res) => {
  res.status(404).json({ message: "Route not found." });
});

app.use((error, req, res, next) => {
  console.error(error);

  if (error.name === "MulterError") {
    return res.status(400).json({ message: error.message });
  }

  if (error.statusCode) {
    return res.status(error.statusCode).json({ message: error.message });
  }

  if (error.message) {
    return res.status(500).json({ message: error.message });
  }

  return res.status(500).json({ message: "Something went wrong." });
});

const port = Number(process.env.PORT || 5000);
const server = http.createServer(app);
initSocket(server);

const startServer = async () => {
  try {
    await connectDB();
    server.listen(port, () => {
      console.log(`GMinsta backend running on port ${port}`);
    });
  } catch (error) {
    console.error("Failed to start server", error);
    process.exit(1);
  }
};

if (require.main === module) {
  startServer();
}

module.exports = {
  app,
  server,
  startServer
};
