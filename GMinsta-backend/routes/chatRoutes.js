const express = require("express");
const authMiddleware = require("../middleware/authMiddleware");
const {
  getMutualFollowers,
  sendMessage,
  getChatHistory
} = require("../controllers/chatController");

const router = express.Router();

router.get("/mutuals", authMiddleware, getMutualFollowers);
router.post("/messages/:receiverId", authMiddleware, sendMessage);
router.get("/messages/:receiverId", authMiddleware, getChatHistory);

module.exports = router;
