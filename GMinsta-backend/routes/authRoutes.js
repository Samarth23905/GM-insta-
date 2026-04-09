const express = require("express");
const multer = require("multer");
const path = require("path");
const authMiddleware = require("../middleware/authMiddleware");
const {
  register,
  login,
  getCurrentUser,
  searchUsers,
  getUserProfile,
  updateProfilePicture
} = require("../controllers/authController");

const router = express.Router();

const profileUpload = multer({
  storage: multer.diskStorage({
    destination: path.resolve(__dirname, "..", "uploads", "profiles"),
    filename: (req, file, callback) => {
      const extension = path.extname(file.originalname) || ".jpg";
      const safeBaseName = path
        .basename(file.originalname, extension)
        .replace(/[^a-zA-Z0-9-_]/g, "-");

      callback(null, `${Date.now()}-${safeBaseName}${extension}`);
    }
  }),
  fileFilter: (req, file, callback) => {
    if (!file.mimetype.startsWith("image/")) {
      const error = new Error("Profile picture must be an image.");
      error.statusCode = 400;
      return callback(error);
    }

    return callback(null, true);
  },
  limits: {
    fileSize: 10 * 1024 * 1024
  }
});

router.post("/register", register);
router.post("/login", login);
router.get("/me", authMiddleware, getCurrentUser);
router.get("/search", authMiddleware, searchUsers);
router.get("/users/:userId", authMiddleware, getUserProfile);
router.put(
  "/profile-picture",
  authMiddleware,
  profileUpload.single("profilePic"),
  updateProfilePicture
);

module.exports = router;
