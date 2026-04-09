const User = require("../models/User");

exports.sendFollowRequest = async (req, res, next) => {
  try {
    const targetUserId = req.params.userId;
    const currentUserId = req.user.userId;

    if (String(targetUserId) === String(currentUserId)) {
      return res
        .status(400)
        .json({ message: "You cannot follow yourself." });
    }

    const [currentUser, targetUser] = await Promise.all([
      User.findById(currentUserId),
      User.findById(targetUserId)
    ]);

    if (!currentUser || !targetUser) {
      return res.status(404).json({ message: "User not found." });
    }

    const alreadyFollowing = targetUser.followers.some(
      (id) => String(id) === String(currentUserId)
    );

    if (alreadyFollowing) {
      return res.json({ message: "You already follow this user." });
    }

    const alreadyRequested = targetUser.followRequests.some(
      (id) => String(id) === String(currentUserId)
    );

    if (alreadyRequested) {
      return res.json({ message: "Follow request already sent." });
    }

    targetUser.followRequests.push(currentUserId);
    await targetUser.save();

    return res.status(201).json({ message: "Follow request sent." });
  } catch (error) {
    return next(error);
  }
};

exports.respondToFollowRequest = async (req, res, next) => {
  try {
    const { requesterId } = req.params;
    const action = String(req.body.action || "").toLowerCase();

    if (!["accept", "reject"].includes(action)) {
      return res
        .status(400)
        .json({ message: "Action must be accept or reject." });
    }

    const [currentUser, requester] = await Promise.all([
      User.findById(req.user.userId),
      User.findById(requesterId)
    ]);

    if (!currentUser || !requester) {
      return res.status(404).json({ message: "User not found." });
    }

    const hadRequest = currentUser.followRequests.some(
      (id) => String(id) === String(requesterId)
    );

    if (!hadRequest) {
      return res.status(404).json({ message: "Follow request not found." });
    }

    currentUser.followRequests = currentUser.followRequests.filter(
      (id) => String(id) !== String(requesterId)
    );

    if (action === "accept") {
      if (!currentUser.followers.some((id) => String(id) === String(requesterId))) {
        currentUser.followers.push(requesterId);
      }

      if (!requester.following.some((id) => String(id) === String(req.user.userId))) {
        requester.following.push(req.user.userId);
      }

      if (!currentUser.following.some((id) => String(id) === String(requesterId))) {
        currentUser.following.push(requesterId);
      }

      if (!requester.followers.some((id) => String(id) === String(req.user.userId))) {
        requester.followers.push(req.user.userId);
      }
    }

    await Promise.all([currentUser.save(), requester.save()]);

    return res.json({
      message:
        action === "accept"
          ? "Follow request accepted."
          : "Follow request rejected."
    });
  } catch (error) {
    return next(error);
  }
};

exports.listIncomingRequests = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.userId).populate(
      "followRequests",
      "username profilePic bio followers following"
    );

    if (!user) {
      return res.status(404).json({ message: "User not found." });
    }

    return res.json({
      requests: user.followRequests.map((requestUser) => ({
        ...requestUser.toObject({ versionKey: false }),
        followersCount: requestUser.followers.length,
        followingCount: requestUser.following.length
      }))
    });
  } catch (error) {
    return next(error);
  }
};
