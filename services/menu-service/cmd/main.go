// Package main is the entrypoint for menu-service.
//
// Keeps /healthz, /readyz, /metrics; wires config, Postgres (schema-per-service
// with embedded migrations), a Redis cache for menu/search results, and the menu
// HTTP API.

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

	"github.com/cloudkitchen/menu-service/internal/config"
	"github.com/cloudkitchen/menu-service/internal/handler"
	"github.com/cloudkitchen/menu-service/internal/middleware"
	"github.com/cloudkitchen/menu-service/internal/repository"
	"github.com/cloudkitchen/menu-service/internal/service"
	"github.com/cloudkitchen/menu-service/internal/telemetry"
	"github.com/cloudkitchen/menu-service/migrations"
	"github.com/cloudkitchen/menu-service/pkg/cache"
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
		slog.Error("menu-service failed", "error", err)
		os.Exit(1)
	}
}

func run() error {
	cfg := config.Load()

	logger := slog.New(slog.NewJSONHandler(
		os.Stdout,
		&slog.HandlerOptions{Level: parseLevel(cfg.LogLevel)},
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

	pool, err := repository.Connect(ctx, cfg.DSN(), cfg.DBSchema)
	if err != nil {
		return fmt.Errorf("db connect failed: %w", err)
	}
	defer pool.Close()

	if err := repository.RunMigrations(ctx, pool, cfg.DBSchema, migrations.FS, "."); err != nil {
		return fmt.Errorf("migrations failed: %w", err)
	}

	// Redis is best-effort. The service can operate without caching.
	var menuCache *cache.Cache
	if cc, err := cache.New(cfg.RedisAddr, cfg.RedisPassword); err != nil {
		logger.Warn("redis unavailable, caching disabled", "error", err)
	} else {
		menuCache = cc
		defer menuCache.Close()
	}

	repo := repository.NewMenuRepository(pool)
	svc := service.NewMenuService(repo, menuCache)
	h := handler.NewMenuHandler(svc)

	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
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
		rctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
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

	router.GET("/metrics", gin.WrapH(promhttp.Handler()))
	h.Register(router, cfg.JWTSecret)

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
