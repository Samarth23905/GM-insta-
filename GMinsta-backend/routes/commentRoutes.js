const express = require("express");
const authMiddleware = require("../middleware/authMiddleware");
const {
  addComment,
  getCommentsByPost,
  updateComment
} = require("../controllers/commentController");

const router = express.Router();

router.post("/:postId", authMiddleware, addComment);
router.get("/:postId", authMiddleware, getCommentsByPost);
router.put("/edit/:commentId", authMiddleware, updateComment);

module.exports = router;
