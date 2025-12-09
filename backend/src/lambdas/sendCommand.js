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

  const { deviceId, command } = body;

  if (!deviceId || !command) {
    return {
      statusCode: 400,
      body: JSON.stringify({ message: "deviceId and command are required" }),
    };
  }

  const now = new Date().toISOString();

  await ddb
    .update({
      TableName: tableName,
      Key: { deviceId },
      UpdateExpression:
        "SET lastCommand = :cmd, lastCommandAt = :ts",
      ExpressionAttributeValues: {
        ":cmd": command,
        ":ts": now,
      },
    })
    .promise();

  return {
    statusCode: 200,
    body: JSON.stringify({ ok: true }),
  };
};
