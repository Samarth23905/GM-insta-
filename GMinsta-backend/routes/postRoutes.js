const express = require("express");
const multer = require("multer");
const path = require("path");
const authMiddleware = require("../middleware/authMiddleware");
const {
  createPost,
  getFeed,
  getReels,
  reactToPost,
  deletePost,
  getPostsByUser,
  addStory,
  getActiveStories
} = require("../controllers/postController");

const router = express.Router();

const createStorage = (destination) =>
  multer.diskStorage({
    destination: path.resolve(__dirname, "..", destination),
    filename: (req, file, callback) => {
      const extension = path.extname(file.originalname) || ".jpg";
      const safeBaseName = path
        .basename(file.originalname, extension)
        .replace(/[^a-zA-Z0-9-_]/g, "-");

      callback(null, `${Date.now()}-${safeBaseName}${extension}`);
    }
  });

const postMediaFilter = (req, file, callback) => {
  if (
    !file.mimetype.startsWith("image/") &&
    !file.mimetype.startsWith("video/")
  ) {
    const error = new Error("Posts accept only image or video uploads.");
    error.statusCode = 400;
    return callback(error);
  }

  return callback(null, true);
};

const storyFilter = (req, file, callback) => {
  if (
    !file.mimetype.startsWith("image/") &&
    !file.mimetype.startsWith("video/")
  ) {
    const error = new Error("Stories accept only image or video uploads.");
    error.statusCode = 400;
    return callback(error);
  }

  return callback(null, true);
};

const postUpload = multer({
  storage: createStorage(path.join("uploads", "posts")),
  fileFilter: postMediaFilter,
  limits: {
    fileSize: 60 * 1024 * 1024
  }
});

const storyUpload = multer({
  storage: createStorage(path.join("uploads", "stories")),
  fileFilter: storyFilter,
  limits: {
    fileSize: 30 * 1024 * 1024
  }
});

router.post(
  "/",
  authMiddleware,
  postUpload.fields([
    { name: "media", maxCount: 1 },
    { name: "image", maxCount: 1 }
  ]),
  createPost
);
router.get("/feed", authMiddleware, getFeed);
router.get("/reels", authMiddleware, getReels);
router.get("/user/:userId", authMiddleware, getPostsByUser);
router.put("/:postId/react", authMiddleware, reactToPost);
router.delete("/:postId", authMiddleware, deletePost);
router.post(
  "/stories",
  authMiddleware,
  storyUpload.single("media"),
  addStory
);
router.get("/stories/active", authMiddleware, getActiveStories);

module.exports = router;
