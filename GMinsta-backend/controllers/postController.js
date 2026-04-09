const Post = require("../models/Post");
const Comment = require("../models/Comment");
const Story = require("../models/Story");
const User = require("../models/User");

const normalizeMediaPath = (filePath) => {
  const normalizedPath = String(filePath || "").replace(/\\/g, "/");
  const uploadsIndex = normalizedPath.lastIndexOf("/uploads/");

  if (uploadsIndex >= 0) {
    return normalizedPath.substring(uploadsIndex);
  }

  if (normalizedPath.startsWith("uploads/")) {
    return `/${normalizedPath}`;
  }

  return normalizedPath.startsWith("/") ? normalizedPath : `/${normalizedPath}`;
};

const sanitizePost = (postDoc, viewerId) => {
  const post = postDoc.toObject({ versionKey: false });

  post.media = post.media || post.image;
  post.mediaType = post.mediaType || "image";
  post.likesCount = post.likes.length;
  post.dislikesCount = post.dislikes.length;
  post.hasLiked = post.likes.some((id) => String(id) === String(viewerId));
  post.hasDisliked = post.dislikes.some((id) => String(id) === String(viewerId));

  return post;
};

const cleanupExpiredStories = async () => {
  await User.updateMany(
    {},
    {
      $pull: {
        stories: {
          expiresAt: { $lte: new Date() }
        }
      }
    }
  );
};

exports.createPost = async (req, res, next) => {
  try {
    const uploadedFile =
      req.files?.media?.[0] || req.files?.image?.[0] || req.file || null;

    if (!uploadedFile) {
      return res.status(400).json({ message: "Post media is required." });
    }

    const mediaPath = normalizeMediaPath(uploadedFile.path);
    const mediaType = uploadedFile.mimetype.startsWith("video")
      ? "video"
      : "image";

    const post = await Post.create({
      userId: req.user.userId,
      caption: req.body.caption || "",
      media: mediaPath,
      image: mediaPath,
      mediaType
    });

    const populated = await Post.findById(post._id).populate(
      "userId",
      "username profilePic"
    );

    return res.status(201).json({
      message: "Post created successfully.",
      post: sanitizePost(populated, req.user.userId)
    });
  } catch (error) {
    return next(error);
  }
};

exports.getFeed = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.userId).select("following");
    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    const feedUserIds = [...user.following.map(String), String(req.user.userId)];

    let posts = await Post.find({
      userId: { $in: feedUserIds }
    })
      .populate("userId", "username profilePic")
      .sort({ createdAt: -1 });

    if (posts.length === 0) {
      posts = await Post.find({})
        .populate("userId", "username profilePic")
        .sort({ createdAt: -1 })
        .limit(50);
    }

    return res.json({
      posts: posts.map((post) => sanitizePost(post, req.user.userId))
    });
  } catch (error) {
    return next(error);
  }
};

exports.reactToPost = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const reaction = String(req.body.reaction || "").toLowerCase();

    if (!["like", "dislike", "clear"].includes(reaction)) {
      return res.status(400).json({
        message: "Reaction must be like, dislike, or clear."
      });
    }

    const post = await Post.findById(postId);
    if (!post) {
      return res.status(404).json({ message: "Post not found." });
    }

    const viewerId = String(req.user.userId);
    post.likes = post.likes.filter((id) => String(id) !== viewerId);
    post.dislikes = post.dislikes.filter((id) => String(id) !== viewerId);

    if (reaction === "like") {
      post.likes.push(req.user.userId);
    }

    if (reaction === "dislike") {
      post.dislikes.push(req.user.userId);
    }

    await post.save();

    const populated = await Post.findById(post._id).populate(
      "userId",
      "username profilePic"
    );

    return res.json({
      message: "Reaction updated successfully.",
      post: sanitizePost(populated, req.user.userId)
    });
  } catch (error) {
    return next(error);
  }
};

exports.getPostsByUser = async (req, res, next) => {
  try {
    const posts = await Post.find({ userId: req.params.userId })
      .populate("userId", "username profilePic")
      .sort({ createdAt: -1 });

    return res.json({
      posts: posts.map((post) => sanitizePost(post, req.user.userId))
    });
  } catch (error) {
    return next(error);
  }
};

exports.getReels = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.userId).select("following");
    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    const visibleUserIds = [...user.following.map(String), String(req.user.userId)];

    let posts = await Post.find({
      userId: { $in: visibleUserIds },
      mediaType: "video"
    })
      .populate("userId", "username profilePic")
      .sort({ createdAt: -1 });

    if (posts.length === 0) {
      posts = await Post.find({ mediaType: "video" })
        .populate("userId", "username profilePic")
        .sort({ createdAt: -1 })
        .limit(50);
    }

    return res.json({
      reels: posts.map((post) => sanitizePost(post, req.user.userId))
    });
  } catch (error) {
    return next(error);
  }
};

exports.deletePost = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const post = await Post.findById(postId);

    if (!post) {
      return res.status(404).json({ message: "Post not found." });
    }

    if (String(post.userId) !== String(req.user.userId)) {
      return res
        .status(403)
        .json({ message: "You can only delete your own posts." });
    }

    await Promise.all([
      Comment.deleteMany({ postId: post._id }),
      Post.deleteOne({ _id: post._id })
    ]);

    return res.json({ message: "Post deleted successfully." });
  } catch (error) {
    return next(error);
  }
};

exports.addStory = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "Story media is required." });
    }

    const mediaType = req.file.mimetype.startsWith("video")
      ? "video"
      : "image";

    const story = await Story.create({
      userId: req.user.userId,
      media: normalizeMediaPath(req.file.path),
      mediaType
    });

    await cleanupExpiredStories();

    await User.findByIdAndUpdate(req.user.userId, {
      $push: {
        stories: {
          storyId: story._id,
          media: story.media,
          mediaType: story.mediaType,
          createdAt: story.createdAt,
          expiresAt: story.expiresAt
        }
      }
    });

    const populatedStory = await Story.findById(story._id).populate(
      "userId",
      "username profilePic"
    );

    return res.status(201).json({
      message: "Story added successfully.",
      story: populatedStory
    });
  } catch (error) {
    return next(error);
  }
};

exports.getActiveStories = async (req, res, next) => {
  try {
    await cleanupExpiredStories();

    const user = await User.findById(req.user.userId).select("following");
    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    const visibleUserIds = [...user.following.map(String), String(req.user.userId)];

    const stories = await Story.find({
      userId: { $in: visibleUserIds },
      expiresAt: { $gt: new Date() }
    })
      .populate("userId", "username profilePic")
      .sort({ createdAt: 1 });

    const grouped = stories.reduce((accumulator, story) => {
      const key = String(story.userId._id);
      if (!accumulator[key]) {
        accumulator[key] = {
          user: story.userId,
          stories: []
        };
      }
      accumulator[key].stories.push(story);
      return accumulator;
    }, {});

    return res.json({
      stories: Object.values(grouped)
    });
  } catch (error) {
    return next(error);
  }
};
