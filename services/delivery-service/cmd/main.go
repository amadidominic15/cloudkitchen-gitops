
// Package main is the entrypoint for the delivery-service.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cloudkitchen/delivery-service/internal/config"
	"github.com/cloudkitchen/delivery-service/internal/handler"
	"github.com/cloudkitchen/delivery-service/internal/middleware"
	"github.com/cloudkitchen/delivery-service/internal/repository"
	"github.com/cloudkitchen/delivery-service/internal/service"
	"github.com/cloudkitchen/delivery-service/internal/telemetry"
	"github.com/cloudkitchen/delivery-service/migrations"
	"github.com/cloudkitchen/delivery-service/pkg/broker"
	
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/gin-gonic/gin"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

func levelFromString(s string) slog.Level {
	switch s {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

func main() {
	if err := run(); err != nil {
		slog.Error("delivery-service failed", "error", err)
		os.Exit(1)
	}
}

func run() error {
	cfg := config.Load()

	logger := slog.New(slog.NewJSONHandler(
		os.Stdout,
		&slog.HandlerOptions{
			Level: levelFromString(cfg.LogLevel),
		},
	))
	slog.SetDefault(logger)

	ctx := context.Background()

	// Initialize OpenTelemetry tracing.
	shutdownTracing, err := telemetry.InitTracing(ctx, cfg.ServiceName)
	if err != nil {
		return fmt.Errorf("initialize tracing: %w", err)
	}

	// Register tracing shutdown before other resources so it runs last.
	defer func() {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := shutdownTracing(shutdownCtx); err != nil {
			logger.Error("tracing shutdown failed", "error", err)
		}
	}()

	// Connect to PostgreSQL.
	pool, err := repository.NewPool(ctx, cfg.DSN())
	if err != nil {
		return fmt.Errorf("postgres connect failed: %w", err)
	}
	defer pool.Close()

	// Apply database migrations.
	if err := repository.Migrate(ctx, pool, cfg.DBSchema, migrations.FS()); err != nil {
		return fmt.Errorf("database migrations failed: %w", err)
	}
	logger.Info("migrations applied", "schema", cfg.DBSchema)

	// Connect to NATS.
	b, err := broker.New(cfg.NATSURL, logger)
	if err != nil {
		return fmt.Errorf("nats connect failed: %w", err)
	}
	defer b.Close()

	// Initialize delivery service.
	deliveryRepo := repository.NewDeliveryRepository(pool)
	deliverySvc := service.NewDeliveryService(deliveryRepo, b, logger)

	// Start payment.completed event consumer.
	if err := b.Consume(
		"delivery-service.events",
		[]string{"payment.completed"},
		deliverySvc.HandleEvent,
	); err != nil {
		return fmt.Errorf("start event consumer: %w", err)
	}

	// Configure Gin.
	gin.SetMode(gin.ReleaseMode)

	router := gin.New()
	router.Use(
		otelgin.Middleware(cfg.ServiceName),
		gin.Recovery(),
		middleware.Logging(logger),
		middleware.Metrics(),
	)

	// Liveness probe.
	router.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": cfg.ServiceName,
		})
	})

	// Readiness probe.
	router.GET("/readyz", func(c *gin.Context) {
		rctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
		defer cancel()

		if err := pool.Ping(rctx); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"status": "db unavailable",
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"status":  "ready",
			"service": cfg.ServiceName,
		})
	})

	// Prometheus metrics endpoint.
	router.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// Register delivery API routes.
	handler.New(deliverySvc, cfg.JWTSecret).Register(router)

	// Configure HTTP server.
	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}

	serverErr := make(chan error, 1)

	go func() {
		logger.Info(
			"server starting",
			"service", cfg.ServiceName,
			"port", cfg.Port,
		)

		if err := srv.ListenAndServe(); err != nil &&
			!errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
	}()

	// Wait for termination signal or server failure.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	defer signal.Stop(quit)

	select {
	case sig := <-quit:
		logger.Info(
			"shutdown signal received",
			"signal", sig.String(),
		)

	case err := <-serverErr:
		return fmt.Errorf("HTTP server failed: %w", err)
	}

	logger.Info("server shutting down", "service", cfg.ServiceName)

	// Gracefully shut down HTTP server.
	shutdownCtx, cancel := context.WithTimeout(
		context.Background(),
		10*time.Second,
	)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)

		if closeErr := srv.Close(); closeErr != nil {
			logger.Error("forced server close failed", "error", closeErr)
		}

		return fmt.Errorf("HTTP server shutdown failed: %w", err)
	}

	logger.Info("server stopped", "service", cfg.ServiceName)

	return nil
}
