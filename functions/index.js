/**
 * Bunk Planner viral referral — callable Functions.
 *
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions,hosting
 *
 * Enable in console (project bunk-planner-2935b):
 *   Auth → Anonymous, Firestore, Functions, Hosting.
 */

const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

const GRANT_DAYS = 7;
const MAX_REDEEMS_PER_WINDOW = 10;
const WINDOW_MS = 30 * 24 * 60 * 60 * 1000;
const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const INVITE_HOST = "https://schoolabe.com/i/";

function codeFromUid(uid) {
  const hash = crypto.createHash("sha256").update(uid).digest();
  let n = hash.readUInt32BE(0) >>> 2;
  let code = "";
  for (let i = 0; i < 6; i += 1) {
    code = ALPHABET[n & 31] + code;
    n >>>= 5;
  }
  return code;
}

function normalizeCode(raw) {
  if (!raw || typeof raw !== "string") return "";
  return raw
    .toUpperCase()
    .replace(/[IL]/g, "1")
    .replace(/O/g, "0")
    .replace(/U/g, "V")
    .replace(/[^0-9A-HJKMNP-TV-Z]/g, "");
}

function requireUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return uid;
}

exports.ensureInviteCode = onCall({ region: "us-central1" }, async (request) => {
  const uid = requireUid(request);
  const code = codeFromUid(uid);
  const inviteRef = db.collection("invites").doc(code);
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const invite = await tx.get(inviteRef);
    if (invite.exists === false) {
      tx.set(inviteRef, {
        ownerUid: uid,
        createdAt: FieldValue.serverTimestamp(),
        redeemCount: 0,
      });
    }
    tx.set(
      userRef,
      { inviteCode: code, updatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
  });

  const snap = await inviteRef.get();
  return {
    code,
    url: `${INVITE_HOST}${code}`,
    redeemCount: snap.get("redeemCount") || 0,
  };
});

exports.redeemInvite = onCall({ region: "us-central1" }, async (request) => {
  const inviteeUid = requireUid(request);
  const code = normalizeCode(request.data && request.data.code);
  if (code.length !== 6) {
    throw new HttpsError("invalid-argument", "not-found");
  }

  const inviteRef = db.collection("invites").doc(code);
  const redemptionRef = db.collection("redemptions").doc(inviteeUid);

  await db.runTransaction(async (tx) => {
    const [invite, existing] = await Promise.all([
      tx.get(inviteRef),
      tx.get(redemptionRef),
    ]);

    if (existing.exists) {
      throw new HttpsError("already-exists", "already_redeemed");
    }
    if (invite.exists === false) {
      throw new HttpsError("not-found", "not-found");
    }

    const ownerUid = invite.get("ownerUid");
    if (ownerUid === inviteeUid) {
      throw new HttpsError("failed-precondition", "self_redeem");
    }

    const ownerRef = db.collection("users").doc(ownerUid);
    const owner = await tx.get(ownerRef);
    const history = owner.get("recentRedeemsAt") || [];
    const now = Date.now();
    const recent = history.filter((ms) => now - ms < WINDOW_MS);
    if (recent.length >= MAX_REDEEMS_PER_WINDOW) {
      throw new HttpsError("resource-exhausted", "cap_reached");
    }

    tx.set(redemptionRef, {
      code,
      ownerUid,
      at: FieldValue.serverTimestamp(),
    });
    tx.update(inviteRef, { redeemCount: FieldValue.increment(1) });
    tx.set(
      ownerRef,
      {
        pendingAdFreeDays: FieldValue.increment(GRANT_DAYS),
        recentRedeemsAt: [...recent, now],
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  return { grantDays: GRANT_DAYS };
});

exports.claimReferralRewards = onCall({ region: "us-central1" }, async (request) => {
  const uid = requireUid(request);
  const userRef = db.collection("users").doc(uid);
  let grantedDays = 0;
  let redeemCount = 0;
  let code = codeFromUid(uid);

  await db.runTransaction(async (tx) => {
    const user = await tx.get(userRef);
    grantedDays = user.get("pendingAdFreeDays") || 0;
    if (grantedDays > 0) {
      tx.set(
        userRef,
        {
          pendingAdFreeDays: 0,
          claimedAdFreeDays: FieldValue.increment(grantedDays),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    if (user.get("inviteCode")) {
      code = user.get("inviteCode");
    }
  });

  const invite = await db.collection("invites").doc(code).get();
  if (invite.exists) {
    redeemCount = invite.get("redeemCount") || 0;
  }

  return { grantedDays, redeemCount, code };
});
