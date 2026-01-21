package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	cfg, err := LoadConfig()
	if err != nil {
		log.Fatal(err)
	}

	db, err := pgxpool.New(context.Background(), cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	api := &API{
		db:                 db,
		httpClient:         &http.Client{Timeout: 5 * time.Second},
		nominatimUserAgent: cfg.NominatimUserAgent,
	}

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   cfg.CORSOrigins,
		AllowedMethods:   []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})

	r.Route("/api", func(r chi.Router) {
		r.Post("/data", api.HandleReceiveData)
		r.Get("/dashboard", api.HandleDashboard)
		r.Get("/measurements", api.HandleMeasurementsList)
		r.Get("/measurements/{id}", api.HandleMeasurementDetail)
	})

	log.Printf("API listening on %s", cfg.Addr())
	log.Fatal(http.ListenAndServe(cfg.Addr(), r))
}
