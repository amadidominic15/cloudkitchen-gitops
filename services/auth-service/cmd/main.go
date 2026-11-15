
package main

import (
	"context"
	"errors"
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

// parseLevel maps a LOG_LEVEL string to an slog.Level.
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
	cfg := config.Load()

	logger := slog.New(
		slog.NewJSONHandler(
			os.Stdout,
			&slog.HandlerOptions{Level: parseLevel(cfg.LogLevel)},
		),
	)
	slog.SetDefault(logger)

	// Application context.
	ctx := context.Background()

	// --- OpenTelemetry tracing initialization. ---
	shutdownTracing, err := telemetry.InitTracing(ctx, cfg.ServiceName)
	if err != nil {
		logger.Error("tracing initialization failed", "error", err)
		os.Exit(1)
	}

	// --- Database: connect, ensure schema, run migrations. ---
	pool, err := repository.Connect(ctx, cfg.DSN(), cfg.DBSchema)
	if err != nil {
		logger.Error("db connect failed", "error", err)
		os.Exit(1)
	}

	// --- Messaging: NATS broker. ---
	b, err := broker.New(cfg.NATSURL, logger)
	if err != nil {
		logger.Error("nats connect failed", "error", err)
		pool.Close()
		_ = shutdownTracing(ctx)
		logger.Error("nats connect failed", "error", err)
		os.Exit(1)
	}

	// --- Wire layers: repository -> service -> handler. ---
	userRepo := repository.NewUserRepository(pool)
	authSvc := service.NewAuthService(userRepo, b, cfg.JWTSecret, cfg.JWTExpiry)
	authHandler := handler.NewAuthHandler(authSvc)

	gin.SetMode(gin.ReleaseMode)

	router := gin.New()

	// Register tracing before application middleware.
	router.Use(
		otelgin.Middleware(cfg.ServiceName),
		gin.Recovery(),
		middleware.RequestLogger(logger),
		middleware.Metrics(cfg.ServiceName),
	)

	router.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": cfg.ServiceName,
		})
	})

	router.GET("/readyz", func(c *gin.Context) {
		if err := pool.Ping(c.Request.Context()); err != nil {
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

	router.GET("/metrics", gin.WrapH(promhttp.Handler()))

	authHandler.Register(router, cfg.JWTSecret)

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}

	// Start HTTP server.
	serverErrors := make(chan error, 1)

	go func() {
		logger.Info("server starting",
			"service", cfg.ServiceName,
			"port", cfg.Port,
		)

		if err := srv.ListenAndServe(); err != nil &&
			!errors.Is(err, http.ErrServerClosed) {
			serverErrors <- err
		}
	}()

	// Wait for termination signal or server failure.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	defer signal.Stop(quit)

	select {
	case sig := <-quit:
		logger.Info("shutdown signal received", "signal", sig.String())
	case err := <-serverErrors:
		logger.Error("server failed", "error", err)
	}

	logger.Info("server shutting down", "service", cfg.ServiceName)

	// Gracefully shut down HTTP server.
	shutdownCtx, cancel := context.WithTimeout(
		context.Background(),
		10*time.Second,
	)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("HTTP server shutdown failed", "error", err)
	}

	// Close NATS and PostgreSQL.
	b.Close()
	pool.Close()

	// Flush and shut down OpenTelemetry last.
	tracingCtx, tracingCancel := context.WithTimeout(
		context.Background(),
		10*time.Second,
	)
	defer tracingCancel()

	if err := shutdownTracing(tracingCtx); err != nil {
		logger.Error("tracing shutdown failed", "error", err)
	}

	logger.Info("server stopped", "service", cfg.ServiceName)
}
