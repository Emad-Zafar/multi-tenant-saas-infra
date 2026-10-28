'use strict';

// Worker autoscaler: scales the ECS worker service on BullMQ queue depth.
// Runs every ~1 minute via EventBridge Scheduler. Arrival rate is derived from the
// ACTUAL elapsed time between runs (persisted state), since 90s isn't expressible.

const { Queue } = require('bullmq');
const IORedis = require('ioredis');
const { ECSClient, DescribeServicesCommand, UpdateServiceCommand } = require('@aws-sdk/client-ecs');

const {
  REDIS_HOST,
  REDIS_PORT = '6379',
  CLUSTER,
  SERVICE,
  T_WORKER_PER_MIN = '1500',
  D_SECONDS = '180',
  N_MIN = '2',
  N_MAX = '6',
  EXCLUDE_QUEUES = '',
} = process.env;

const STATE_KEY = 'autoscaler:state';
const tWorkerPerMin = Number(T_WORKER_PER_MIN);
const dSeconds = Number(D_SECONDS);
const nMin = Number(N_MIN);
const nMax = Number(N_MAX);
const excluded = new Set(EXCLUDE_QUEUES.split(',').map((s) => s.trim()).filter(Boolean));

const ecs = new ECSClient({}); // region from the Lambda runtime env
const clamp = (n, lo, hi) => Math.min(Math.max(n, lo), hi);

exports.handler = async () => {
  const connection = new IORedis({
    host: REDIS_HOST,
    port: Number(REDIS_PORT),
    maxRetriesPerRequest: null,
  });

  try {
    // 1) Auto-discover queues by scanning bull:*:meta keys.
    const metaKeys = [];
    let cursor = '0';
    do {
      const [next, keys] = await connection.scan(cursor, 'MATCH', 'bull:*:meta', 'COUNT', 200);
      cursor = next;
      metaKeys.push(...keys);
    } while (cursor !== '0');

    const queueNames = metaKeys
      .map((k) => k.slice('bull:'.length, k.length - ':meta'.length))
      .filter((name) => !excluded.has(name));

    // 2) Backlog B = sum(waiting + active) across discovered queues.
    let B = 0;
    for (const name of queueNames) {
      const q = new Queue(name, { connection });
      try {
        const [waiting, active] = await Promise.all([q.getWaitingCount(), q.getActiveCount()]);
        B += waiting + active;
      } finally {
        await q.close();
      }
    }

    // 3) Arrival rate (jobs/sec) from the previous sample using ACTUAL elapsed time.
    const now = Date.now();
    const rawState = await connection.get(STATE_KEY);
    const prev = rawState ? JSON.parse(rawState) : null;

    let lambdaRate = 0;
    if (prev && prev.ts) {
      const elapsedSec = Math.max((now - prev.ts) / 1000, 1);
      lambdaRate = Math.max((B - prev.B) / elapsedSec, 0);
    }

    // 4) Desired worker count.
    const throughputPerSec = tWorkerPerMin / 60;
    const nDesiredRaw = Math.ceil((B / dSeconds + lambdaRate) / throughputPerSec);
    const nDesired = clamp(nDesiredRaw, nMin, nMax);

    // 5) Current desiredCount + hysteresis.
    const desc = await ecs.send(new DescribeServicesCommand({ cluster: CLUSTER, services: [SERVICE] }));
    const current = desc.services && desc.services[0] ? desc.services[0].desiredCount : nMin;

    let lowCount = prev && typeof prev.lowCount === 'number' ? prev.lowCount : 0;
    let target = current;

    if (nDesired > current) {
      target = nDesired; // scale OUT immediately
      lowCount = 0;
    } else if (nDesired < current) {
      lowCount += 1; // scale IN only after 3 consecutive low samples
      if (lowCount >= 3) {
        target = current - 1; // step down one task at a time
        lowCount = 0;
      }
    } else {
      lowCount = 0;
    }
    target = clamp(target, nMin, nMax);

    if (target !== current) {
      await ecs.send(new UpdateServiceCommand({ cluster: CLUSTER, service: SERVICE, desiredCount: target }));
    }

    await connection.set(STATE_KEY, JSON.stringify({ B, ts: now, lowCount }));
    console.log(JSON.stringify({ queues: queueNames.length, B, lambdaRate, nDesired, current, target }));
    return { B, nDesired, current, target };
  } finally {
    await connection.quit();
  }
};
