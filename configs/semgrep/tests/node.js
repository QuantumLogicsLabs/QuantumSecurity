// Test cases for ../rules/node.yml. This file is insecure on purpose and is never run.
// "ruleid" marks a line the rule must report; "ok" marks a line it must leave alone.
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const cors = require("cors");
const multer = require("multer");
const express = require("express");
const User = require("./models/User");

const app = express();

// ruleid: quantum-secret-env-fallback
const jwtSecret = process.env.JWT_SECRET || "changeme";
// ruleid: quantum-secret-env-fallback
const dbPassword = process.env.DB_PASSWORD ?? "dev";
// ok: quantum-secret-env-fallback
const port = process.env.PORT || "5000";
// ok: quantum-secret-env-fallback
const requiredSecret = process.env.JWT_SECRET;

function issueTokens(user) {
  // ruleid: quantum-jwt-no-expiry
  const forever = jwt.sign({ id: user.id }, jwtSecret);
  // ruleid: quantum-jwt-no-expiry
  const alsoForever = jwt.sign({ id: user.id }, jwtSecret, { algorithm: "HS256" });
  // ok: quantum-jwt-no-expiry
  const shortLived = jwt.sign({ id: user.id }, jwtSecret, { expiresIn: "15m" });
  return [forever, alsoForever, shortLived];
}

// ruleid: quantum-cors-allow-all
app.use(cors());
// ruleid: quantum-cors-allow-all
app.use(cors({ origin: "*" }));
// ruleid: quantum-cors-allow-all
app.use(cors({ origin: true, credentials: true }));
// ok: quantum-cors-allow-all
app.use(cors({ origin: ["https://app.example.com"], credentials: true }));

// ruleid: quantum-multer-no-limits
const uploadAnything = multer({ dest: "uploads/" });
// ok: quantum-multer-no-limits
const uploadLimited = multer({ dest: "uploads/", limits: { fileSize: 5 * 1024 * 1024 } });

async function hashPasswords(password) {
  // ruleid: quantum-bcrypt-low-rounds
  const weak = await bcrypt.hash(password, 4);
  // ok: quantum-bcrypt-low-rounds
  const strong = await bcrypt.hash(password, 12);
  return [weak, strong];
}

app.get("/users", async (req, res) => {
  // ruleid: quantum-nosql-query-from-request
  const users = await User.find(req.query);
  res.json(users);
});

app.post("/login", async (req, res) => {
  const { email } = req.body;
  // ruleid: quantum-nosql-operator-injection
  const destructured = await User.findOne({ email });
  // ruleid: quantum-nosql-operator-injection
  const direct = await User.findOne({ email: req.body.email });
  // ok: quantum-nosql-operator-injection
  const converted = await User.findOne({ email: String(email) });
  res.json({ destructured, direct, converted });
});

app.post("/users", async (req, res) => {
  // ruleid: quantum-mass-assignment
  const created = await User.create(req.body);
  // ruleid: quantum-mass-assignment
  const updated = await User.findByIdAndUpdate(req.params.id, req.body, { new: true });
  // ok: quantum-mass-assignment
  const picked = await User.create({ name: String(req.body.name) });
  res.json({ created, updated, picked });
});

app.post("/session", (req, res) => {
  // ruleid: quantum-cookie-not-httponly
  res.cookie("session", req.sessionID);
  // ruleid: quantum-cookie-not-httponly
  res.cookie("session", req.sessionID, { secure: true });
  // ok: quantum-cookie-not-httponly
  res.cookie("session", req.sessionID, { httpOnly: true, secure: true, sameSite: "strict" });
  res.end();
});

app.get("/report", (req, res) => {
  try {
    res.json(buildReport());
  } catch (error) {
    // ruleid: quantum-error-stack-in-response
    res.send(error.stack);
  }
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  // ok: quantum-error-stack-in-response
  res.status(500).json({ message: "Something went wrong" });
});

app.use((err, req, res, next) => {
  // ruleid: quantum-error-stack-in-response
  res.status(500).json({ message: err.message, stack: err.stack });
});

module.exports = { app, port, dbPassword, requiredSecret, uploadAnything, uploadLimited, hashPasswords };
