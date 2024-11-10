import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

// Example HTTP function
export const helloWorld = onRequest(async (request, response) => {
  // Using the logger
  logger.info("Hello World function executed!", {
    requestUrl: request.url,
    timestamp: new Date().toISOString()
  });

  // Send response
  response.json({
    message: "Hello from Firebase Functions!",
    timestamp: new Date().toISOString()
  });
});