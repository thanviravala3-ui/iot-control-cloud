const AWS = require("aws-sdk");
const ddb = new AWS.DynamoDB.DocumentClient();

const tableName = process.env.CONNECTIONS_TABLE;

exports.handler = async (event) => {
  console.log("Connection event:", JSON.stringify(event));

  const { requestContext } = event;
  const connectionId = requestContext.connectionId;
  const routeKey = requestContext.routeKey;

  if (routeKey === "$connect") {
    await ddb
      .put({
        TableName: tableName,
        Item: {
          connectionId,
          connectedAt: new Date().toISOString(),
        },
      })
      .promise();
  } else if (routeKey === "$disconnect") {
    await ddb
      .delete({
        TableName: tableName,
        Key: { connectionId },
      })
      .promise();
  }

  return {
    statusCode: 200,
    body: "OK",
  };
};
