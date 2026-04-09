const User = require("../models/User");

const syncAcceptedFollowsForUser = async (userId) => {
  const currentUser = await User.findById(userId);
  if (!currentUser) {
    return null;
  }

  const relatedIds = [
    ...new Set([
      ...currentUser.followers.map(String),
      ...currentUser.following.map(String)
    ])
  ];

  if (relatedIds.length === 0) {
    return currentUser;
  }

  const relatedUsers = await User.find({
    _id: { $in: relatedIds }
  });

  let currentUserChanged = false;

  for (const otherUser of relatedUsers) {
    const otherId = String(otherUser._id);
    const currentId = String(currentUser._id);
    const currentFollowsOther = currentUser.following.some(
      (id) => String(id) === otherId
    );
    const otherFollowsCurrent = otherUser.following.some(
      (id) => String(id) === currentId
    );
    const currentHasOtherAsFollower = currentUser.followers.some(
      (id) => String(id) === otherId
    );
    const otherHasCurrentAsFollower = otherUser.followers.some(
      (id) => String(id) === currentId
    );
    const hasAcceptedConnectionTrace =
      currentFollowsOther ||
      otherFollowsCurrent ||
      currentHasOtherAsFollower ||
      otherHasCurrentAsFollower;

    // Repair older accepted follow pairs that were saved only partially.
    if (hasAcceptedConnectionTrace) {
      let otherUserChanged = false;

      if (!currentFollowsOther) {
        currentUser.following.push(otherUser._id);
        currentUserChanged = true;
      }

      if (!otherFollowsCurrent) {
        otherUser.following.push(currentUser._id);
        otherUserChanged = true;
      }

      if (!currentHasOtherAsFollower) {
        currentUser.followers.push(otherUser._id);
        currentUserChanged = true;
      }

      if (!otherHasCurrentAsFollower) {
        otherUser.followers.push(currentUser._id);
        otherUserChanged = true;
      }

      if (otherUserChanged) {
        await otherUser.save();
      }
    }
  }

  if (currentUserChanged) {
    await currentUser.save();
  }

  return currentUser;
};

module.exports = {
  syncAcceptedFollowsForUser
};
