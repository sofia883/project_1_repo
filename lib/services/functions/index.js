const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendChatNotification = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const recipientId = message.recipientId;
    
    const recipientDoc = await admin.firestore()
      .collection('users')
      .doc(recipientId)
      .get();
      
    const fcmToken = recipientDoc.data().fcmToken;
    
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: 'New message',
        body: message.message,
      },
    });
  });