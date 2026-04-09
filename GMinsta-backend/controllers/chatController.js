const Message = require("../models/Message");
const User = require("../models/User");
const { getIo } = require("../utils/socket");
const { syncAcceptedFollowsForUser } = require("../utils/followSync");

const findMutualUsers = async (userId) => {
  const syncedUser = await syncAcceptedFollowsForUser(userId);
  const currentUser = syncedUser
    ? await User.findById(userId).select(
        "followers following username profilePic"
      )
    : null;

  if (!currentUser) {
    return null;
  }

  const followerIds = currentUser.followers.map(String);
  const followingIds = currentUser.following.map(String);
  const mutualIds = followerIds.filter((id) => followingIds.includes(id));

  return User.find({
    _id: { $in: mutualIds }
  }).select("username profilePic bio followers following");
};

const canChatWith = async (userId, otherId) => {
  const mutuals = await findMutualUsers(userId);
  if (!mutuals) {
    return false;
  }

  return mutuals.some((user) => String(user._id) === String(otherId));
};

exports.getMutualFollowers = async (req, res, next) => {
  try {
    const users = await findMutualUsers(req.user.userId);
    if (!users) {
      return res.status(404).json({ message: "User not found." });
    }

    return res.json({
      users: users.map((user) => ({
        ...user.toObject({ versionKey: false }),
        followersCount: user.followers.length,
        followingCount: user.following.length
      }))
    });
  } catch (error) {
    return next(error);
  }
};

exports.sendMessage = async (req, res, next) => {
  try {
    const { receiverId } = req.params;
    const messageText = String(req.body.messageText || "").trim();

    if (!messageText) {
      return res.status(400).json({ message: "Message text is required." });
    }

    const allowed = await canChatWith(req.user.userId, receiverId);
    if (!allowed) {
      return res
        .status(403)
        .json({ message: "Only mutual followers can chat." });
    }

    const message = await Message.create({
      senderId: req.user.userId,
      receiverId,
      messageText
    });

    const populated = await Message.findById(message._id)
      .populate("senderId", "username profilePic")
      .populate("receiverId", "username profilePic");

    const io = getIo();
    io.to(`user:${req.user.userId}`).emit("message:new", populated);
    io.to(`user:${receiverId}`).emit("message:new", populated);

    return res.status(201).json({
      message: "Message sent successfully.",
      data: populated
    });
  } catch (error) {
    return next(error);
  }
};

exports.getChatHistory = async (req, res, next) => {
  try {
    const { receiverId } = req.params;

    const allowed = await canChatWith(req.user.userId, receiverId);
    if (!allowed) {
      return res
        .status(403)
        .json({ message: "Only mutual followers can view this chat." });
    }

    const messages = await Message.find({
      $or: [
        { senderId: req.user.userId, receiverId },
        { senderId: receiverId, receiverId: req.user.userId }
      ]
    })
      .populate("senderId", "username profilePic")
      .populate("receiverId", "username profilePic")
      .sort({ sentAt: 1 });

    return res.json({ messages });
  } catch (error) {
    return next(error);
  }
};
