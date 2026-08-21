package middleware

import (
	"net/http"

	"gateway/config"
)

// BodyLimit caps the request body for the handlers it wraps.
func BodyLimit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		r.Body = http.MaxBytesReader(w, r.Body, int64(config.MaxBodyMB)<<20)
		next.ServeHTTP(w, r)
	})
}

// Throttle rejects a caller that exceeds the configured burst.
func Throttle(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !allow(r.RemoteAddr, config.RateLimitBurst) {
			http.Error(w, "slow down", http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func allow(key string, burst int) bool {
	bucket, ok := buckets[key]
	if !ok {
		bucket = burst
	}
	if bucket <= 0 {
		return false
	}
	buckets[key] = bucket - 1
	return true
}

var buckets = map[string]int{}
