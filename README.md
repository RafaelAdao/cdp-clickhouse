# CDP on clickhouse

The first priority of this project is to explore Clickhouse by designing a simple CDP use case. The project is a work in progress and the main goal is to learn and share the knowledge.

## What is CDP?

Customer Data Platform (CDP) is a type of software which creates a persistent, unified customer database that is accessible to other systems. Data is pulled from multiple sources, cleaned and combined to create a single customer profile. This structured data is then made available to other marketing systems.

## What is Clickhouse?

ClickHouse is an column-oriented database management system that allows generating analytical data reports in real-time. It is capable of processing hundreds of millions to more than a billion rows and tens of gigabytes of data per single server per second.

## Use cases

In this project, we will explore the following use cases:

- **Segmentation**: Create segments based on user properties.
- **Reflect changes**: Reflect changes in the segment membership when the user properties change.
- **Notification**: Send notifications when a user enters/exits a segment.

## Working in progress

This project is a work in progress. Below are the tasks that are planned to be implemented:

- [x] clickhouse setup with docker compose
- [ ] create tables for
  - [x] entities
  - [ ] criteria
  - [ ] segment_membership
  - [ ] events
- [ ] send notifications when a user enters/exits a segment

## Getting started

To get started, you need to have Docker and Docker Compose installed on your machine. Then, you can run the following commands:

```bash
docker compose up
```

This command will start the Clickhouse server and the Clickhouse client. You can access the Clickhouse client by running the following command:

```bash
docker exec -it clickhouse clickhouse-client
```

or you can access the Clickhouse client through the browser by visiting the following URL http://localhost:18123/play?password=changeme

On the examples.sql file, you can find some examples of queries that you can run on the Clickhouse client.

## Explanation

Blog post comming soon.

## Cleaning up

```sh
docker compose down -v
```
