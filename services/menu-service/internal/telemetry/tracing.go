package telemetry

import (
    "context"
    "errors"

    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

func InitTracing(
    ctx context.Context,
    serviceName string,
) (func(context.Context) error, error) {

    exporter, err := otlptracegrpc.New(
        ctx,
    )
    if err != nil {
        return nil, err
    }

    res, err := resource.New(
        ctx,
        resource.WithAttributes(
            semconv.ServiceName(serviceName),
            attribute.String("deployment.environment", "dev"),
        ),
    )
    if err != nil {
        return nil, errors.Join(err, exporter.Shutdown(ctx))
    }

    provider := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
        sdktrace.WithSampler(
            sdktrace.ParentBased(
                sdktrace.TraceIDRatioBased(0.10),
            ),
        ),
    )

    otel.SetTracerProvider(provider)

    return provider.Shutdown, nil
}