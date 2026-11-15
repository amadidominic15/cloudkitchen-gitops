// Package main is the entrypoint for the notification-service.
//
// It boots config, Postgres (pgxpool + embedded migrations), the NATS broker,
// the HTTP API and a consumer goroutine that records notifications for
// order.placed, payment.completed and delivery.updated, then blocks until
// SIGINT/SIGTERM for a graceful shutdown.

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

	"github.com/cloudkitchen/notification-service/internal/config"
	"github.com/cloudkitchen/notification-service/internal/handler"
	"github.com/cloudkitchen/notification-service/internal/middleware"
	"github.com/cloudkitchen/notification-service/internal/repository"
	"github.com/cloudkitchen/notification-service/internal/service"
	"github.com/cloudkitchen/notification-service/internal/telemetry"
	"github.com/cloudkitchen/notification-service/migrations"
	"github.com/cloudkitchen/notification-service/pkg/broker"
	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
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
		slog.Error("notification-service failed", "error", err)
		os.Exit(1)
	}
}

func run() error {
	cfg := config.Load()

	logger := slog.New(slog.NewJSONHandler(
		os.Stdout,
		&slog.HandlerOptions{Level: levelFromString(cfg.LogLevel)},
	))
	slog.SetDefault(logger)

	ctx := context.Background()

	shutdownTracing, err := telemetry.InitTracing(ctx, cfg.ServiceName)
	if err != nil {
		return fmt.Errorf("initialize tracing: %w", err)
	}
	defer func() {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := shutdownTracing(shutdownCtx); err != nil {
			logger.Error("tracing shutdown failed", "error", err)
		}
	}()

	pool, err := repository.NewPool(ctx, cfg.DSN())
	if err != nil {
		return fmt.Errorf("postgres connect failed: %w", err)
	}
	defer pool.Close()

	if err := repository.Migrate(ctx, pool, cfg.DBSchema, migrations.FS()); err != nil {
		return fmt.Errorf("migrations failed: %w", err)
	}
	logger.Info("migrations applied", "schema", cfg.DBSchema)

	b, err := broker.New(cfg.NATSURL, logger)
	if err != nil {
		return fmt.Errorf("nats connect failed: %w", err)
	}
	defer b.Close()

	notifRepo := repository.NewNotificationRepository(pool)
	notifSvc := service.NewNotificationService(notifRepo, logger)

	if err := b.Consume(
		"notification-service.events",
		[]string{"order.placed", "payment.completed", "delivery.updated"},
		notifSvc.HandleEvent,
	); err != nil {
		return fmt.Errorf("start notification consumer: %w", err)
	}

	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(
		otelgin.Middleware(cfg.ServiceName),
		gin.Recovery(),
		middleware.Logging(logger),
		middleware.Metrics(),
	)

	router.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": cfg.ServiceName,
		})
	})

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

	router.GET("/metrics", gin.WrapH(promhttp.Handler()))
	handler.New(notifSvc, cfg.JWTSecret).Register(router)

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}

	serverErr := make(chan error, 1)

	go func() {
		logger.Info("server starting", "service", cfg.ServiceName, "port", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	defer signal.Stop(quit)

	select {
	case sig := <-quit:
		logger.Info("shutdown signal received", "signal", sig.String())
	case err := <-serverErr:
		return fmt.Errorf("HTTP server failed: %w", err)
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		_ = srv.Close()
		return fmt.Errorf("HTTP server shutdown failed: %w", err)
	}

	logger.Info("server stopped", "service", cfg.ServiceName)
	return nil
}
