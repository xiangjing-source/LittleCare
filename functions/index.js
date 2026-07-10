const admin = require("firebase-admin");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

exports.notifyCareEventCreated = onDocumentCreated(
  "care_events/{careId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const care = snapshot.data();
    const toUserId = care.to_user_id;
    const fromUserId = care.from_user_id;
    const groupId = care.group_id;
    if (!toUserId || !fromUserId || !groupId || toUserId === fromUserId) {
      return;
    }
    const preferences = await loadPreferences(toUserId);
    if (!preferences.careNotificationsEnabled) return;
    if (preferences.mutedGroupIds.has(groupId)) return;
    if (isQuietNow(preferences)) return;

    const [sender, group] = await Promise.all([
      loadUserName(fromUserId),
      loadGroupName(groupId),
    ]);
    const isResponse = care.care_type === "response";
    await sendToUser(toUserId, {
      title: isResponse ? `${sender}回复了你` : `${sender}发来关心`,
      body: care.message || (isResponse ? "有一条新的回复" : "有一条新的关心"),
      data: {
        type: isResponse ? "care_response" : "care",
        care_id: event.params.careId,
        group_id: groupId,
        group_name: group,
      },
    });
  },
);

exports.notifyRecordShareCreated = onDocumentCreated(
  "record_shares/{shareId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const share = snapshot.data();
    const ownerUserId = share.owner_user_id || share.owner_account_id;
    const groupId = share.group_id;
    if (!ownerUserId || !groupId) return;

    const [ownerName, groupName, memberships] = await Promise.all([
      loadUserName(ownerUserId),
      loadGroupName(groupId),
      db
        .collection("group_memberships")
        .where("group_id", "==", groupId)
        .where("status", "==", "active")
        .get(),
    ]);
    const recipients = memberships.docs
      .map((document) => document.data().user_id)
      .filter((userId) => userId && userId !== ownerUserId);
    await Promise.all(
      recipients.map(async (userId) => {
        const preferences = await loadPreferences(userId);
        if (!preferences.healthNotificationsEnabled) return;
        if (preferences.mutedGroupIds.has(groupId)) return;
        if (isQuietNow(preferences)) return;
        await sendToUser(userId, {
          title: `${ownerName}更新了健康记录`,
          body: `已分享给“${groupName}”`,
          data: {
            type: "health_record_shared",
            record_id: share.record_id || "",
            group_id: groupId,
            group_name: groupName,
          },
        });
      }),
    );
  },
);

async function sendToUser(userId, payload) {
  const tokens = await db
    .collection("device_tokens")
    .where("user_id", "==", userId)
    .where("enabled", "==", true)
    .get();
  if (tokens.empty) return;
  const messages = tokens.docs
    .map((document) => document.data().token)
    .filter(Boolean)
    .map((token) => ({
      token,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: stringifyData(payload.data),
      android: {
        priority: "high",
        notification: {
          channelId: "littlecare_updates",
        },
      },
    }));
  if (messages.length === 0) return;
  const response = await messaging.sendEach(messages);
  await Promise.all(
    response.responses.map(async (result, index) => {
      if (result.success) return;
      logger.warn("FCM send failed", {
        userId,
        error: result.error && result.error.code,
      });
      const code = result.error && result.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        await tokens.docs[index].ref.set(
          {
            enabled: false,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }
    }),
  );
}

async function loadPreferences(userId) {
  const snapshot = await db.collection("notification_preferences").doc(userId).get();
  const data = snapshot.data() || {};
  return {
    careNotificationsEnabled: data.care_notifications_enabled !== false,
    healthNotificationsEnabled: data.health_notifications_enabled !== false,
    quietHoursEnabled: data.quiet_hours_enabled !== false,
    quietHoursStart: data.quiet_hours_start || "22:00",
    quietHoursEnd: data.quiet_hours_end || "08:00",
    mutedGroupIds: new Set(data.muted_group_ids || []),
  };
}

async function loadUserName(userId) {
  const snapshot = await db.collection("users").doc(userId).get();
  return (snapshot.data() && snapshot.data().display_name) || "家人";
}

async function loadGroupName(groupId) {
  const snapshot = await db.collection("groups").doc(groupId).get();
  return (snapshot.data() && snapshot.data().name) || "当前群组";
}

function isQuietNow(preferences) {
  if (!preferences.quietHoursEnabled) return false;
  const now = new Date();
  const minutes = now.getHours() * 60 + now.getMinutes();
  const start = parseClock(preferences.quietHoursStart);
  const end = parseClock(preferences.quietHoursEnd);
  if (start === end) return false;
  if (start < end) return minutes >= start && minutes < end;
  return minutes >= start || minutes < end;
}

function parseClock(value) {
  const [hour, minute] = String(value).split(":").map((part) => Number(part));
  return (Number.isFinite(hour) ? hour : 0) * 60 +
    (Number.isFinite(minute) ? minute : 0);
}

function stringifyData(data) {
  return Object.fromEntries(
    Object.entries(data || {}).map(([key, value]) => [key, String(value)]),
  );
}
