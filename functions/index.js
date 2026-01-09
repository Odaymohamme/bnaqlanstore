const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.notifyAdminOnNewOrder = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snap, context) => {

    const orderId = context.params.orderId;
    const orderData = snap.data();

    // جلب توكنات الأدمن
    const tokensSnap = await admin.firestore()
      .collection("admin_fcm_tokens")
      .get();

    if (tokensSnap.empty) {
      console.log("لا يوجد توكنات أدمن");
      return null;
    }

    const tokens = tokensSnap.docs.map(doc => doc.id);

    const payload = {
      notification: {
        title: "📦 طلب جديد",
        body: `طلب جديد من العميل رقم ${orderData.customer_id}`,
      },
      data: {
        order_id: orderId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    await admin.messaging().sendToDevice(tokens, payload);

    console.log("تم إرسال إشعار للأدمن");
    return null;
});
