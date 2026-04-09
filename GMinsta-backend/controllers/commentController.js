const Comment = require("../models/Comment");
const Post = require("../models/Post");

exports.addComment = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const commentText = String(req.body.commentText || "").trim();

    if (!commentText) {
      return res.status(400).json({ message: "Comment text is required." });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ message: "Post not found." });
    }

    const comment = await Comment.create({
      postId,
      userId: req.user.userId,
      commentText
    });

    const populated = await Comment.findById(comment._id).populate(
      "userId",
      "username profilePic"
    );

    return res.status(201).json({
      message: "Comment added successfully.",
      comment: populated
    });
  } catch (error) {
    return next(error);
  }
};

exports.getCommentsByPost = async (req, res, next) => {
  try {
    const comments = await Comment.find({ postId: req.params.postId })
      .populate("userId", "username profilePic")
      .sort({ createdAt: 1 });

    return res.json({
      comments,
      count: comments.length
    });
  } catch (error) {
    return next(error);
  }
};

exports.updateComment = async (req, res, next) => {
  try {
    const { commentId } = req.params;
    const commentText = String(req.body.commentText || "").trim();

    if (!commentText) {
      return res.status(400).json({ message: "Comment text is required." });
    }

    const comment = await Comment.findById(commentId);
    if (!comment) {
      return res.status(404).json({ message: "Comment not found." });
    }

    if (String(comment.userId) !== String(req.user.userId)) {
      return res
        .status(403)
        .json({ message: "You can only edit your own comments." });
    }

    comment.commentText = commentText;
    await comment.save();

    const populated = await Comment.findById(comment._id).populate(
      "userId",
      "username profilePic"
    );

    return res.json({
      message: "Comment updated successfully.",
      comment: populated
    });
  } catch (error) {
    return next(error);
  }
};
