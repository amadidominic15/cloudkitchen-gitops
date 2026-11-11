#!/usr/bin/env python3
"""
Generate one Grafana dashboard ConfigMap YAML file for each CloudKitchen service.

The script uses one shared dashboard definition and writes eight independent
Kubernetes manifests into the output directory.

Usage:
    python3 generate.py
    python3 generate.py --output-dir ./gitops/monitoring/dashboards

Apply all generated manifests:
    kubectl apply -f ./generated-dashboards/

The ConfigMaps retain the monitoring namespace and grafana_dashboard=1 label
used by the Grafana sidecar.
"""

import argparse
import json
from pathlib import Path

SERVICES = [
    "auth-service",
    "user-service",
    "restaurant-service",
    "menu-service",
    "order-service",
    "payment-service",
    "delivery-service",
    "notification-service",
]


def _grid(x, y, w, h):
    return {"h": h, "w": w, "x": x, "y": y}


def stat(panel_id, x, y, w, h, title, expr, unit):
    return {
        "id": panel_id,
        "type": "stat",
        "title": title,
        "gridPos": _grid(x, y, w, h),
        "datasource": {"type": "prometheus", "uid": "prometheus"},
        "targets": [{
            "expr": expr,
            "refId": "A",
            "datasource": {"type": "prometheus", "uid": "prometheus"},
        }],
        "fieldConfig": {
            "defaults": {
                "unit": unit,
                "color": {"mode": "thresholds"},
                "thresholds": {
                    "mode": "absolute",
                    "steps": [
                        {"color": "green", "value": None},
                        {"color": "yellow", "value": 1},
                        {"color": "red", "value": 5},
                    ],
                },
            },
            "overrides": [],
        },
        "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "center",
            "orientation": "auto",
            "reduceOptions": {
                "calcs": ["lastNotNull"],
                "fields": "",
                "values": False,
            },
        },
    }


def timeseries(panel_id, x, y, w, h, title, targets, unit):
    return {
        "id": panel_id,
        "type": "timeseries",
        "title": title,
        "gridPos": _grid(x, y, w, h),
        "datasource": {"type": "prometheus", "uid": "prometheus"},
        "targets": [
            {
                "expr": expr,
                "legendFormat": legend,
                "refId": chr(65 + index),
                "datasource": {
                    "type": "prometheus",
                    "uid": "prometheus",
                },
            }
            for index, (expr, legend) in enumerate(targets)
        ],
        "fieldConfig": {
            "defaults": {
                "unit": unit,
                "custom": {
                    "drawStyle": "line",
                    "lineWidth": 1,
                    "fillOpacity": 10,
                    "showPoints": "never",
                },
            },
            "overrides": [],
        },
        "options": {
            "legend": {
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": True,
                "calcs": [],
            },
            "tooltip": {"mode": "multi", "sort": "desc"},
        },
    }


def logs(panel_id, x, y, w, h, title, expr):
    return {
        "id": panel_id,
        "type": "logs",
        "title": title,
        "gridPos": _grid(x, y, w, h),
        "datasource": {"type": "loki", "uid": "loki"},
        "targets": [{
            "expr": expr,
            "refId": "A",
            "datasource": {"type": "loki", "uid": "loki"},
        }],
        "options": {
            "showTime": True,
            "showLabels": False,
            "showCommonLabels": False,
            "wrapLogMessage": False,
            "prettifyLogMessage": False,
            "enableLogDetails": True,
            "dedupStrategy": "none",
            "sortOrder": "Descending",
        },
    }


def dashboard(service):
    """Build the Grafana dashboard JSON for one microservice."""
    panel_id = 0

    def next_id():
        nonlocal panel_id
        panel_id += 1
        return panel_id

    return {
        "annotations": {"list": []},
        "editable": True,
        "fiscalYearStartMonth": 0,
        "graphTooltip": 1,
        "links": [],
        "liveNow": False,
        "panels": [
            # Row 1: top-level service statistics
            stat(
                next_id(), 0, 0, 6, 4, "Requests / sec",
                f'sum(rate(http_requests_total{{service="{service}"}}[5m]))',
                "reqps",
            ),
            stat(
                next_id(), 6, 0, 6, 4, "Error rate (5xx)",
                f'sum(rate(http_requests_total{{service="{service}",status=~"5.."}}[5m]))'
                f' / clamp_min(sum(rate(http_requests_total{{service="{service}"}}[5m])), 1e-9)',
                "percentunit",
            ),
            stat(
                next_id(), 12, 0, 6, 4, "p95 latency",
                f'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{{service="{service}"}}[5m])))',
                "s",
            ),
            stat(
                next_id(), 18, 0, 6, 4, "Pods up",
                f'count(up{{service="{service}"}} == 1)',
                "short",
            ),

            # Row 2: traffic
            timeseries(
                next_id(), 0, 4, 12, 8, "Requests / sec by status",
                [(
                    f'sum by (status) (rate(http_requests_total{{service="{service}"}}[5m]))',
                    "{{status}}",
                )],
                "reqps",
            ),
            timeseries(
                next_id(), 12, 4, 12, 8, "Requests / sec by path",
                [(
                    f'topk(5, sum by (path) (rate(http_requests_total{{service="{service}"}}[5m])))',
                    "{{path}}",
                )],
                "reqps",
            ),

            # Row 3: latency percentiles
            timeseries(
                next_id(), 0, 12, 24, 8, "HTTP latency (p50 / p95 / p99)",
                [
                    (
                        f'histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{{service="{service}"}}[5m])))',
                        "p50",
                    ),
                    (
                        f'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{{service="{service}"}}[5m])))',
                        "p95",
                    ),
                    (
                        f'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{{service="{service}"}}[5m])))',
                        "p99",
                    ),
                ],
                "s",
            ),

            # Row 4: pod resources
            timeseries(
                next_id(), 0, 20, 12, 8, "CPU usage (cores, per pod)",
                [(
                    f'sum by (pod) (rate(container_cpu_usage_seconds_total{{namespace="cloudkitchen",pod=~"{service}.*",container!="",container!="POD"}}[5m]))',
                    "{{pod}}",
                )],
                "short",
            ),
            timeseries(
                next_id(), 12, 20, 12, 8, "Memory (MiB, per pod)",
                [(
                    f'sum by (pod) (container_memory_working_set_bytes{{namespace="cloudkitchen",pod=~"{service}.*",container!="",container!="POD"}}) / 1024 / 1024',
                    "{{pod}}",
                )],
                "decmbytes",
            ),

            # Row 5: logs
            logs(
                next_id(), 0, 28, 24, 10, "Logs (Loki)",
                f'{{namespace="cloudkitchen", app="{service}"}}',
            ),
        ],
        "refresh": "30s",
        "schemaVersion": 39,
        "tags": ["cloudkitchen", service],
        "time": {"from": "now-1h", "to": "now"},
        "title": f"CloudKitchen / {service}",
        "uid": f"ck-{service}",
        "version": 1,
        "weekStart": "",
    }


def yaml_configmap(service):
    """Serialize one dashboard as a Kubernetes ConfigMap YAML document."""
    dashboard_json = json.dumps(dashboard(service), indent=2)
    configmap_name = f"grafana-dashboard-{service}"
    data_key = f"{service}.json"

    lines = [
        "apiVersion: v1",
        "kind: ConfigMap",
        "metadata:",
        f"  name: {configmap_name}",
        "  namespace: monitoring",
        "  labels:",
        '    grafana_dashboard: "1"',
        '    app.kubernetes.io/part-of: "cloudkitchen-dashboards"',
        "data:",
        f"  {data_key}: |",
    ]
    lines.extend(f"    {line}" for line in dashboard_json.splitlines())
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(
        description="Generate individual Grafana ConfigMaps for all CloudKitchen services."
    )
    parser.add_argument(
        "--output-dir",
        default="generated-dashboards",
        help="Directory for the eight generated YAML files (default: generated-dashboards).",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for service in SERVICES:
        output_file = output_dir / f"{service}.yaml"
        output_file.write_text(yaml_configmap(service), encoding="utf-8")
        print(f"Generated: {output_file}")

    print(f"\nGenerated {len(SERVICES)} dashboard ConfigMaps in: {output_dir}")


if __name__ == "__main__":
    main()
