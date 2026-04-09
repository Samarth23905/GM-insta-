const express = require("express");
const authMiddleware = require("../middleware/authMiddleware");
const {
  sendFollowRequest,
  respondToFollowRequest,
  listIncomingRequests
} = require("../controllers/followController");

const router = express.Router();

router.post("/request/:userId", authMiddleware, sendFollowRequest);
router.post("/respond/:requesterId", authMiddleware, respondToFollowRequest);
router.get("/requests", authMiddleware, listIncomingRequests);

module.exports = router;
