
#!/usr/bin/env python3

import json
from pathlib import Path

import yaml


# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------

ROOT = Path(__file__).resolve().parents[1]

OUTPUT_DIR = ROOT / "gitops" / "monitoring" / "dashboard"

NAMESPACE = "observability"

PROMETHEUS_UID = "prometheus"
LOKI_UID = "loki"

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


# ---------------------------------------------------------
# YAML formatting
# ---------------------------------------------------------

class LiteralString(str):
    pass


def represent_literal_string(dumper, value):
    return dumper.represent_scalar(
        "tag:yaml.org,2002:str",
        value,
        style="|",
    )


yaml.SafeDumper.add_representer(
    LiteralString,
    represent_literal_string,
)


# ---------------------------------------------------------
# Dashboard panel builders
# ---------------------------------------------------------

def prometheus_target(expression, legend="{{service}}"):
    return {
        "datasource": {
            "type": "prometheus",
            "uid": PROMETHEUS_UID,
        },
        "editorMode": "code",
        "expr": expression,
        "legendFormat": legend,
        "range": True,
        "refId": "A",
    }


def loki_target(service):
    return {
        "datasource": {
            "type": "loki",
            "uid": LOKI_UID,
        },
        "editorMode": "code",
        "expr": (
            '{namespace="cloudkitchen", '
            f'service="{service}"'
            '}'
        ),
        "queryType": "range",
        "refId": "A",
    }


def timeseries_panel(
    panel_id,
    title,
    expression,
    unit="short",
    description="",
):
    return {
        "id": panel_id,
        "title": title,
        "type": "timeseries",
        "description": description,
        "datasource": {
            "type": "prometheus",
            "uid": PROMETHEUS_UID,
        },
        "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0 if panel_id % 2 else 12,
            "y": ((panel_id - 1) // 2) * 8,
        },
        "fieldConfig": {
            "defaults": {
                "unit": unit,
                "color": {
                    "mode": "palette-classic",
                },
                "custom": {
                    "drawStyle": "line",
                    "lineInterpolation": "smooth",
                    "lineWidth": 2,
                    "fillOpacity": 10,
                    "showPoints": "never",
                    "spanNulls": False,
                },
            },
            "overrides": [],
        },
        "options": {
            "legend": {
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": True,
            },
            "tooltip": {
                "mode": "multi",
                "sort": "desc",
            },
        },
        "targets": [
            prometheus_target(expression)
        ],
    }


def stat_panel(
    panel_id,
    title,
    expression,
    unit="short",
):
    return {
        "id": panel_id,
        "title": title,
        "type": "stat",
        "datasource": {
            "type": "prometheus",
            "uid": PROMETHEUS_UID,
        },
        "gridPos": {
            "h": 5,
            "w": 6,
            "x": ((panel_id - 1) % 4) * 6,
            "y": 0,
        },
        "fieldConfig": {
            "defaults": {
                "unit": unit,
                "color": {
                    "mode": "thresholds",
                },
                "thresholds": {
                    "mode": "absolute",
                    "steps": [
                        {
                            "color": "green",
                            "value": None,
                        },
                        {
                            "color": "red",
                            "value": 1,
                        },
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
        "targets": [
            prometheus_target(expression)
        ],
    }


def logs_panel(panel_id, service):
    return {
        "id": panel_id,
        "title": "Application Logs",
        "type": "logs",
        "datasource": {
            "type": "loki",
            "uid": LOKI_UID,
        },
        "gridPos": {
            "h": 12,
            "w": 24,
            "x": 0,
            "y": 24,
        },
        "options": {
            "showTime": True,
            "showLabels": True,
            "showCommonLabels": False,
            "wrapLogMessage": True,
            "sortOrder": "Descending",
            "dedupStrategy": "none",
        },
        "targets": [
            loki_target(service)
        ],
    }


# ---------------------------------------------------------
# Common dashboard structure
# ---------------------------------------------------------

def dashboard_template(title, uid, panels):
    return {
        "id": None,
        "uid": uid,
        "title": title,
        "tags": [
            "cloudkitchen",
            "microservices",
        ],
        "timezone": "browser",
        "schemaVersion": 39,
        "version": 1,
        "refresh": "30s",
        "time": {
            "from": "now-1h",
            "to": "now",
        },
        "timepicker": {},
        "editable": True,
        "graphTooltip": 1,
        "fiscalYearStartMonth": 0,
        "liveNow": False,
        "panels": panels,
    }


# ---------------------------------------------------------
# Individual microservice dashboards
# ---------------------------------------------------------

def service_dashboard(service):
    panels = [
        stat_panel(
            1,
            "Requests per second",
            (
                f'sum(rate(http_requests_total'
                f'{{service="{service}"}}[5m]))'
            ),
            "reqps",
        ),

        stat_panel(
            2,
            "5xx Error rate",
            (
                f'sum(rate(http_requests_total'
                f'{{service="{service}",status=~"5.."}}[5m]))'
                f' / clamp_min(sum(rate(http_requests_total'
                f'{{service="{service}"}}[5m])), 1e-9)'
            ),
            "percentunit",
        ),

        stat_panel(
            3,
            "P95 Request Latency",
            (
                f'histogram_quantile(0.95, '
                f'sum by (le) (rate(http_request_duration_seconds_bucket'
                f'{{service="{service}"}}[5m])))'
            ),
            "s",
        ),

        stat_panel(
            4,
            "Total Requests",
            (
                f'sum(increase(http_requests_total'
                f'{{service="{service}"}}[$__range]))'
            ),
            "short",
        ),

        timeseries_panel(
            5,
            "Request Rate by HTTP Status",
            (
                f'sum by (status) (rate(http_requests_total'
                f'{{service="{service}"}}[5m]))'
            ),
            "reqps",
        ),

        timeseries_panel(
            6,
            "Request Latency - P50, P95 and P99",
            (
                f'histogram_quantile(0.50, '
                f'sum by (le) (rate(http_request_duration_seconds_bucket'
                f'{{service="{service}"}}[5m])))'
            ),
            "s",
        ),

        timeseries_panel(
            7,
            "CPU Usage by Pod",
            (
                f'sum by (pod) (rate(container_cpu_usage_seconds_total'
                f'{{namespace="cloudkitchen",'
                f'pod=~"{service}.*",container!="",container!="POD"}}[5m]))'
            ),
            "cores",
        ),

        timeseries_panel(
            8,
            "Memory Usage by Pod",
            (
                f'sum by (pod) (container_memory_working_set_bytes'
                f'{{namespace="cloudkitchen",'
                f'pod=~"{service}.*",container!="",container!="POD"}})'
            ),
            "bytes",
        ),

        logs_panel(9, service),
    ]

    return dashboard_template(
        title=f"{service.replace('-', ' ').title()} Dashboard",
        uid=service.replace("-", "_"),
        panels=panels,
    )


# ---------------------------------------------------------
# CloudKitchen overview dashboard
# ---------------------------------------------------------

def overview_dashboard():
    panels = [
        stat_panel(
            1,
            "Total Requests per Second",
            "sum(rate(http_requests_total[5m]))",
            "reqps",
        ),

        stat_panel(
            2,
            "Overall 5xx Error Rate",
            (
                'sum(rate(http_requests_total{status=~"5.."}[5m]))'
                ' / clamp_min(sum(rate(http_requests_total[5m])), 1e-9)'
            ),
            "percentunit",
        ),

        stat_panel(
            3,
            "Healthy Prometheus Targets",
            'sum(up{namespace="cloudkitchen"})',
            "short",
        ),

        stat_panel(
            4,
            "Total Requests",
            'sum(increase(http_requests_total[$__range]))',
            "short",
        ),

        timeseries_panel(
            5,
            "Request Rate by Service",
            "sum by (service) (rate(http_requests_total[5m]))",
            "reqps",
        ),

        timeseries_panel(
            6,
            "5xx Error Rate by Service",
            (
                'sum by (service) (rate(http_requests_total'
                '{status=~"5.."}[5m]))'
            ),
            "reqps",
        ),

        timeseries_panel(
            7,
            "P95 Latency by Service",
            (
                'histogram_quantile(0.95, '
                'sum by (service, le) '
                '(rate(http_request_duration_seconds_bucket[5m])))'
            ),
            "s",
        ),

        timeseries_panel(
            8,
            "CPU Usage by Pod",
            (
                'sum by (pod) (rate(container_cpu_usage_seconds_total'
                '{namespace="cloudkitchen",container!="",container!="POD"}[5m]))'
            ),
            "cores",
        ),

        timeseries_panel(
            9,
            "Memory Usage by Pod",
            (
                'sum by (pod) (container_memory_working_set_bytes'
                '{namespace="cloudkitchen",container!="",container!="POD"})'
            ),
            "bytes",
        ),
    ]

    return dashboard_template(
        title="CloudKitchen Overview",
        uid="cloudkitchen_overview",
        panels=panels,
    )


# ---------------------------------------------------------
# Generate Kubernetes ConfigMaps
# ---------------------------------------------------------

def generate_configmap(filename, dashboard):
    dashboard_json = json.dumps(
        dashboard,
        indent=2,
        ensure_ascii=False,
    )

    configmap = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": f"grafana-dashboard-{dashboard['uid']}",
            "namespace": NAMESPACE,
            "labels": {
                "grafana_dashboard": "1",
                "app.kubernetes.io/part-of": "cloudkitchen",
            },
        },
        "data": {
            f"{dashboard['uid']}.json": LiteralString(dashboard_json),
        },
    }

    output_file = OUTPUT_DIR / filename

    output_file.write_text(
        yaml.safe_dump(
            configmap,
            sort_keys=False,
            allow_unicode=True,
        ),
        encoding="utf-8",
    )

    print(f"Generated: {output_file.relative_to(ROOT)}")


# ---------------------------------------------------------
# Main
# ---------------------------------------------------------

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Overview dashboard
    generate_configmap(
        "cloudkitchen-overview.yaml",
        overview_dashboard(),
    )

    # Eight individual service dashboards
    for service in SERVICES:
        dashboard = service_dashboard(service)

        generate_configmap(
            f"{service}.yaml",
            dashboard,
        )

    print("\nSuccessfully generated all 9 Grafana dashboards.")


if __name__ == "__main__":
    main()
