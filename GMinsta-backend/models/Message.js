const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
  {
    senderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true
    },
    receiverId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true
    },
    messageText: {
      type: String,
      required: true,
      trim: true,
      maxlength: 1000
    },
    sentAt: {
      type: Date,
      default: Date.now
    }
  },
  {
    versionKey: false
  }
);

messageSchema.index({ senderId: 1, receiverId: 1, sentAt: 1 });

module.exports = mongoose.model("Message", messageSchema);
