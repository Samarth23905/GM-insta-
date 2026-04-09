const jwt = require("jsonwebtoken");
const Message = require("../models/Message");
const User = require("../models/User");

let ioInstance = null;

const extractToken = (socket) => {
  const authToken = socket.handshake.auth?.token;
  if (authToken) {
    return authToken;
  }

  const header = socket.handshake.headers.authorization;
  if (header && header.startsWith("Bearer ")) {
    return header.split(" ")[1];
  }

  return null;
};

const areMutuals = async (firstId, secondId) => {
  const users = await User.find({
    _id: { $in: [firstId, secondId] }
  }).select("following");

  if (users.length !== 2) {
    return false;
  }

  const first = users.find((user) => String(user._id) === String(firstId));
  const second = users.find((user) => String(user._id) === String(secondId));

  if (!first || !second) {
    return false;
  }

  return (
    first.following.some((id) => String(id) === String(secondId)) &&
    second.following.some((id) => String(id) === String(firstId))
  );
};

const initSocket = (server) => {
  const { Server } = require("socket.io");

  ioInstance = new Server(server, {
    cors: {
      origin: true,
      credentials: true
    }
  });

  ioInstance.use((socket, next) => {
    try {
      const token = extractToken(socket);
      if (!token) {
        return next(new Error("Authentication required"));
      }

      const decoded = jwt.verify(
        token,
        process.env.JWT_SECRET || "super-secret-jwt-key"
      );

      socket.userId = decoded.userId;
      return next();
    } catch (error) {
      return next(new Error("Invalid socket token"));
    }
  });

  ioInstance.on("connection", (socket) => {
    socket.join(`user:${socket.userId}`);

    socket.on("message:send", async (payload, callback) => {
      try {
        const receiverId = payload?.receiverId;
        const messageText = String(payload?.messageText || "").trim();

        if (!receiverId || !messageText) {
          if (callback) {
            callback({ success: false, message: "Receiver and text required." });
          }
          return;
        }

        const allowed = await areMutuals(socket.userId, receiverId);
        if (!allowed) {
          if (callback) {
            callback({
              success: false,
              message: "Only mutual followers can chat."
            });
          }
          return;
        }

        const message = await Message.create({
          senderId: socket.userId,
          receiverId,
          messageText
        });

        const populated = await Message.findById(message._id)
          .populate("senderId", "username profilePic")
          .populate("receiverId", "username profilePic");

        ioInstance.to(`user:${socket.userId}`).emit("message:new", populated);
        ioInstance.to(`user:${receiverId}`).emit("message:new", populated);

        if (callback) {
          callback({ success: true, data: populated });
        }
      } catch (error) {
        if (callback) {
          callback({ success: false, message: "Failed to send message." });
        }
      }
    });
  });

  return ioInstance;
};

const getIo = () => {
  if (!ioInstance) {
    throw new Error("Socket.io not initialized yet.");
  }

  return ioInstance;
};

module.exports = {
  initSocket,
  getIo
};
