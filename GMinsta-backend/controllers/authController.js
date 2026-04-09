const jwt = require("jsonwebtoken");
const User = require("../models/User");
const Post = require("../models/Post");
const { syncAcceptedFollowsForUser } = require("../utils/followSync");

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

const signToken = (userId) =>
  jwt.sign(
    { userId },
    process.env.JWT_SECRET || "super-secret-jwt-key",
    { expiresIn: "7d" }
  );

const sanitizeUser = (userDoc, viewerId = null) => {
  const user = userDoc.toObject({ versionKey: false });
  delete user.password;
  user.followersCount = user.followers.length;
  user.followingCount = user.following.length;
  user.isFollowing = viewerId
    ? user.followers.some((id) => String(id) === String(viewerId))
    : false;
  user.hasRequested = viewerId
    ? user.followRequests.some((id) => String(id) === String(viewerId))
    : false;
  return user;
};

const cleanupUserStories = async (userId) => {
  await User.updateOne(
    { _id: userId },
    {
      $pull: {
        stories: {
          expiresAt: { $lte: new Date() }
        }
      }
    }
  );
};

exports.register = async (req, res, next) => {
  try {
    const { username, email, password, bio, profilePic } = req.body;

    if (!username || !email || !password) {
      return res
        .status(400)
        .json({ message: "Username, email and password are required." });
    }

    const existingUser = await User.findOne({
      $or: [{ email: email.toLowerCase() }, { username: username.trim() }]
    });

    if (existingUser) {
      return res
        .status(409)
        .json({ message: "A user with that username or email already exists." });
    }

    const user = await User.create({
      username: username.trim(),
      email: email.toLowerCase(),
      password,
      bio: bio || undefined,
      profilePic: profilePic || undefined
    });

    const token = signToken(user._id);

    return res.status(201).json({
      message: "Registration successful.",
      token,
      user: sanitizeUser(user)
    });
  } catch (error) {
    return next(error);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { identifier, email, username, password } = req.body;
    const loginIdentifier = String(identifier || email || username || "").trim();

    if (!loginIdentifier || !password) {
      return res
        .status(400)
        .json({ message: "Username or email and password are required." });
    }

    const user = await User.findOne({
      $or: [
        { email: loginIdentifier.toLowerCase() },
        { username: loginIdentifier }
      ]
    }).select("+password");

    if (!user) {
      return res
        .status(401)
        .json({ message: "Invalid username, email or password." });
    }

    const isValidPassword = await user.comparePassword(password);
    if (!isValidPassword) {
      return res
        .status(401)
        .json({ message: "Invalid username, email or password." });
    }

    const token = signToken(user._id);

    return res.json({
      message: "Login successful.",
      token,
      user: sanitizeUser(user)
    });
  } catch (error) {
    return next(error);
  }
};

exports.getCurrentUser = async (req, res, next) => {
  try {
    await cleanupUserStories(req.user.userId);
    const user = await syncAcceptedFollowsForUser(req.user.userId);

    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    return res.json({
      user: sanitizeUser(user, req.user.userId)
    });
  } catch (error) {
    return next(error);
  }
};

exports.searchUsers = async (req, res, next) => {
  try {
    const query = String(req.query.q || "").trim();

    const matcher = query
      ? { username: { $regex: query, $options: "i" } }
      : {};

    const users = await User.find({
      ...matcher,
      _id: { $ne: req.user.userId }
    })
      .limit(25)
      .sort({ username: 1 });

    return res.json({
      users: users.map((user) => sanitizeUser(user, req.user.userId))
    });
  } catch (error) {
    return next(error);
  }
};

exports.getUserProfile = async (req, res, next) => {
  try {
    const { userId } = req.params;

    await cleanupUserStories(userId);
    const user = await syncAcceptedFollowsForUser(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    const postsCount = await Post.countDocuments({ userId });
    const isSelf = String(user._id) === String(req.user.userId);
    const requestSent = user.followRequests.some(
      (id) => String(id) === String(req.user.userId)
    );
    const isFollowing = user.followers.some(
      (id) => String(id) === String(req.user.userId)
    );
    const followsYou = user.following.some(
      (id) => String(id) === String(req.user.userId)
    );

    return res.json({
      user: {
        ...sanitizeUser(user, req.user.userId),
        postsCount
      },
      relationship: {
        isSelf,
        isFollowing,
        requestSent,
        followsYou
      }
    });
  } catch (error) {
    return next(error);
  }
};

exports.updateProfilePicture = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "Profile image is required." });
    }

    const user = await User.findByIdAndUpdate(
      req.user.userId,
      {
        profilePic: normalizeMediaPath(req.file.path)
      },
      {
        new: true
      }
    );

    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    return res.json({
      message: "Profile picture updated successfully.",
      user: sanitizeUser(user, req.user.userId)
    });
  } catch (error) {
    return next(error);
  }
};
