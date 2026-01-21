package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	DatabaseURL        string
	Port               int
	CORSOrigins        []string
	NominatimUserAgent string
}

func LoadConfig() (Config, error) {
	port := mustInt(getenv("PORT", "8080"))

	// Prioritas: DATABASE_URL
	dbURL := os.Getenv("DATABASE_URL")
	if strings.TrimSpace(dbURL) == "" {
		// Fallback: PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE
		host := getenv("PGHOST", "localhost")
		pgport := mustInt(getenv("PGPORT", "5432"))
		user := getenv("PGUSER", "postgres")
		pass := getenv("PGPASSWORD", "postgres")
		dbname := getenv("PGDATABASE", "nutrisync_db")

		// Catatan: untuk production, sebaiknya password di-URL-escape jika ada karakter khusus.
		dbURL = fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=disable",
			user, pass, host, pgport, dbname)
	}

	origins := getenv("CORS_ORIGINS", "*")
	originList := splitComma(origins)

	ua := getenv("NOMINATIM_USER_AGENT", "nutrisync-ta/1.0")

	return Config{
		DatabaseURL:        dbURL,
		Port:               port,
		CORSOrigins:        originList,
		NominatimUserAgent: ua,
	}, nil
}

func (c Config) Addr() string {
	return fmt.Sprintf("0.0.0.0:%d", c.Port)
}

func getenv(k, def string) string {
	v := os.Getenv(k)
	if strings.TrimSpace(v) == "" {
		return def
	}
	return v
}

func mustInt(s string) int {
	n, err := strconv.Atoi(strings.TrimSpace(s))
	if err != nil {
		return 0
	}
	return n
}

func splitComma(s string) []string {
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	if len(out) == 0 {
		return []string{"*"}
	}
	return out
}
