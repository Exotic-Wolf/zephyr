import { Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';

export { admin };

export function ensureFirebaseAdminInitialized(logger: Logger): boolean {
  if (admin.apps.length > 0) {
    return true;
  }

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountJson) {
    return false;
  }

  try {
    const serviceAccount = JSON.parse(serviceAccountJson);
    const databaseURL =
      process.env.FIREBASE_DATABASE_URL ||
      `https://${serviceAccount.project_id}-default-rtdb.asia-southeast1.firebasedatabase.app`;

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL,
    });
    logger.log('Firebase Admin SDK initialized');
    return true;
  } catch (err) {
    logger.error('Failed to initialize Firebase Admin SDK', err);
    return false;
  }
}
