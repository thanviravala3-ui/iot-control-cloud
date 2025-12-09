const AWS = require("aws-sdk");
const ddb = new AWS.DynamoDB.DocumentClient();

const connectionsTable = process.env.CONNECTIONS_TABLE;
const wsEndpoint = process.env.WS_ENDPOINT;

// Management API needs host+stage, not wss://
const api = new AWS.ApiGatewayManagementApi({
  endpoint: wsEndpoint.replace(/^wss?:\/\//, ""),
});

exports.handler = async (event) => {
  console.log("Stream event:", JSON.stringify(event));

  const records = event.Records || [];
  const updates = records
    .filter((r) => r.eventName === "INSERT" || r.eventName === "MODIFY")
    .map((r) => AWS.DynamoDB.Converter.unmarshall(r.dynamodb.NewImage));

  if (updates.length === 0) {
    return { statusCode: 200, body: "No updates" };
  }

  const connections = await ddb
    .scan({ TableName: connectionsTable })
    .promise();

  const posts = [];

  for (const conn of connections.Items || []) {
    for (const device of updates) {
      posts.push(
        api
          .postToConnection({
            ConnectionId: conn.connectionId,
            Data: JSON.stringify({
              type: "deviceUpdate",
              device,
            }),
          })
          .promise()
          .catch((err) => {
            if (err.statusCode === 410) {
              // stale connection, delete it
              return ddb
                .delete({
                  TableName: connectionsTable,
                  Key: { connectionId: conn.connectionId },
                })
                .promise();
            }
            console.error("postToConnection failed", err);
          })
      );
    }
  }

  await Promise.all(posts);

  return {
    statusCode: 200,
    body: "OK",
  };
};
