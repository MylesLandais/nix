#!/usr/bin/env python3
"""Write a synthetic log record and require its presence in local ClickHouse."""

import datetime
import json
import os
from pathlib import Path
import time
import urllib.parse
import urllib.request
import uuid


def check():
    os.umask(0o077)
    source = Path(os.environ["NEBULA_LOG_SOURCE_ROOT"]) / "telemetry"
    source.mkdir(parents=True, exist_ok=True, mode=0o700)
    event_id = str(uuid.uuid4())
    event = {
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "event_id": event_id, "event_name": "log.delivery.canary", "schema_version": 1,
    }
    with (source / "canary.jsonl").open("a") as output:
        output.write(json.dumps(event) + "\n")
        output.flush()
        os.fsync(output.fileno())
    endpoint = os.environ["NEBULA_CLICKHOUSE_ENDPOINT"]
    if endpoint != "http://127.0.0.1:8123":
        raise ValueError("health probe requires the declared local ClickHouse endpoint")
    sql = (
        "SELECT count() AS records FROM nebula_observability.live_logs "
        "WHERE ServiceName='nebula.log-canary' AND LogAttributes['event_id']={probe:String} "
        "AND Timestamp >= now() - INTERVAL 1 HOUR FORMAT JSONEachRow"
    )
    parameters = urllib.parse.urlencode({
        "query": sql, "param_probe": event_id, "max_threads": 1,
        "max_memory_usage": 134217728, "max_execution_time": 3,
    })
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    deadline = time.monotonic() + 25
    records = 0
    failure = None
    while time.monotonic() < deadline:
        try:
            with opener.open(endpoint + "/?" + parameters, timeout=4) as response:
                records = int(json.load(response)["records"])
            if records:
                break
        except (OSError, ValueError, KeyError) as error:
            failure = type(error).__name__
        time.sleep(1)
    result = {
        "checked_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "probe_id": event_id, "delivered": records > 0, "matching_rows": records,
        "last_error_type": failure,
        "scope": "canary file receiver to ClickHouse; not all source coverage or GPU metrics",
    }
    state = Path(os.environ["NEBULA_OTEL_STATE"])
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = state / ("health-" + uuid.uuid4().hex + ".tmp")
    with temporary.open("x") as output:
        json.dump(result, output)
        output.write("\n")
        output.flush()
        os.fsync(output.fileno())
    temporary.replace(state / "health.json")
    print(json.dumps(result))
    return 0 if records else 1


if __name__ == "__main__":
    raise SystemExit(check())
