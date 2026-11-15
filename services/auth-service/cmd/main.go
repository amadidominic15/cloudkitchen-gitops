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

	"github.com/cloudkitchen/auth-service/internal/config"
	"github.com/cloudkitchen/auth-service/internal/handler"
	"github.com/cloudkitchen/auth-service/internal/middleware"
	"github.com/cloudkitchen/auth-service/internal/repository"
	"github.com/cloudkitchen/auth-service/internal/service"
	"github.com/cloudkitchen/auth-service/internal/telemetry"
	"github.com/cloudkitchen/auth-service/migrations"
	"github.com/cloudkitchen/auth-service/pkg/broker"
	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

func parseLevel(s string) slog.Level {
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
		slog.Error("auth-service failed", "error", err)
		os.Exit(1)
	}
}

func run() error {
	cfg := config.Load()

	logger := slog.New(slog.NewJSONHandler(
		os.Stdout,
		&slog.HandlerOptions{
			Level: parseLevel(cfg.LogLevel),
		},
	))
	slog.SetDefault(logger)

	ctx := context.Background()

	// Initialize OpenTelemetry tracing.
	shutdownTracing, err := telemetry.InitTracing(ctx, cfg.ServiceName)
	if err != nil {
		return fmt.Errorf("initialize tracing: %w", err)
	}

	defer func() {
		shutdownCtx, cancel := context.WithTimeout(
			context.Background(),
			10*time.Second,
		)
		defer cancel()

		if err := shutdownTracing(shutdownCtx); err != nil {
			logger.Error("tracing shutdown failed", "error", err)
		}
	}()

	// Connect to PostgreSQL.
	pool, err := repository.Connect(ctx, cfg.DSN(), cfg.DBSchema)
	if err != nil {
		return fmt.Errorf("database connection failed: %w", err)
	}
	defer pool.Close()

	// Run embedded database migrations.
	if err := repository.RunMigrations(
		ctx,
		pool,
		cfg.DBSchema,
		migrations.FS,
		".",
	); err != nil {
		return fmt.Errorf("database migrations failed: %w", err)
	}

	logger.Info("database migrations applied", "schema", cfg.DBSchema)

	// Connect to NATS.
	b, err := broker.New(cfg.NATSURL, logger)
	if err != nil {
		return fmt.Errorf("nats connection failed: %w", err)
	}
	defer b.Close()

	// Wire application layers.
	userRepo := repository.NewUserRepository(pool)

	authSvc := service.NewAuthService(
		userRepo,
		b,
		cfg.JWTSecret,
		cfg.JWTExpiry,
	)

	authHandler := handler.NewAuthHandler(authSvc)

	// Configure Gin.
	gin.SetMode(gin.ReleaseMode)

	router := gin.New()
	router.Use(
		otelgin.Middleware(cfg.ServiceName),
		gin.Recovery(),
		middleware.RequestLogger(logger),
		middleware.Metrics(cfg.ServiceName),
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
		rctx, cancel := context.WithTimeout(
			c.Request.Context(),
			2*time.Second,
		)
		defer cancel()

		if err := pool.Ping(rctx); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"status": "not ready",
				"error":  err.Error(),
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

	// Register authentication API routes.
	authHandler.Register(router, cfg.JWTSecret)

	// Configure HTTP server.
	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}

	serverErr := make(chan error, 1)

	// Start HTTP server.
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

	// Gracefully shut down HTTP server.
	shutdownCtx, cancel := context.WithTimeout(
		context.Background(),
		10*time.Second,
	)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		_ = srv.Close()
		return fmt.Errorf("HTTP server shutdown failed: %w", err)
	}

	logger.Info("server stopped", "service", cfg.ServiceName)

	return nil
}
