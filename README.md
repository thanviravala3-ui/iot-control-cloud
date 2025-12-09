# IoT Control Cloud — Serverless Device Fleet Simulator

End to end serverless device fleet simulator that mirrors real AWS ProServe IoT modernization work.

## What You Build

A simulated device fleet (10–1,000 devices) sending telemetry through:

- API Gateway WebSockets → Lambda → DynamoDB  
- Real time device status dashboard  
- Commands sent from React UI → API Gateway → Lambda → devices  

## Resume Worthy Features

- DynamoDB Streams → Lambda → push deltas back to WebSockets  
- IAM least privilege role for the serverless backend  
- Terraform defines the core cloud stack  
- Optional SQS buffering for event bursts  

## High Level Architecture

1. Devices connect to an API Gateway WebSocket endpoint  
2. Telemetry messages go into a Lambda that writes to DynamoDB  
3. DynamoDB Streams trigger another Lambda that sends deltas back to clients over WebSockets  
4. A React dashboard connects over WebSockets and shows live device status  
5. The dashboard can send commands that are routed back through API Gateway WebSockets to a Lambda that updates the device record

## Tech Stack

- AWS Lambda (Node.js)
- Amazon API Gateway WebSocket API
- Amazon DynamoDB with Streams
- Terraform for infrastructure as code
- React (via CDN) frontend dashboard

## Notes

This repo is meant as a learning + portfolio project to mirror real AWS ProServe IoT modernization patterns.
