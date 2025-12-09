const AWS = require("aws-sdk");
const ddb = new AWS.DynamoDB.DocumentClient();

const tableName = process.env.DEVICES_TABLE;

exports.handler = async (event) => {
  console.log("Incoming event:", JSON.stringify(event));

  let body = {};
  try {
    body = JSON.parse(event.body || "{}");
  } catch (e) {
    console.error("Bad JSON body", e);
    return {
      statusCode: 400,
      body: JSON.stringify({ message: "Invalid JSON" }),
    };
  }

  const { deviceId, temperature, status } = body;

  if (!deviceId) {
    return {
      statusCode: 400,
      body: JSON.stringify({ message: "deviceId is required" }),
    };
  }

  const now = new Date().toISOString();

  await ddb
    .put({
      TableName: tableName,
      Item: {
        deviceId,
        temperature: temperature ?? null,
        status: status || "online",
        lastSeen: now,
      },
    })
    .promise();

  return {
    statusCode: 200,
    body: JSON.stringify({ ok: true }),
  };
};
