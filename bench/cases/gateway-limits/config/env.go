package config

import (
	"os"
	"strconv"
)

// Tunables. Every one of these is documented in deploy/README and can be set
// per environment.
var (
	MaxBodyMB      int
	MaxUploadMB    int
	RateLimitBurst int
	StreamTimeout  int
)

// Storage is read wholesale by the storage package through its struct tags.
type Storage struct {
	Bucket      string `env:"STORAGE_BUCKET"`
	MaxObjectMB int    `env:"STORAGE_MAX_OBJECT_MB" default:"512"`
}

func envInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}

func Load() {
	MaxBodyMB = envInt("MAX_BODY_MB", 32)
	MaxUploadMB = envInt("MAX_UPLOAD_MB", 128)
	RateLimitBurst = envInt("RATE_LIMIT_BURST", 20)
	StreamTimeout = envInt("STREAM_TIMEOUT", 300)
}
