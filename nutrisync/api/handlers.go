package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type API struct {
	db                 *pgxpool.Pool
	httpClient         *http.Client
	nominatimUserAgent string
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]any{"error": msg})
}

func strOrNil(s string) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	return &s
}

func floatPtr(n sql.NullFloat64) *float64 {
	if !n.Valid {
		return nil
	}
	v := n.Float64
	return &v
}

func strPtr(n sql.NullString) *string {
	if !n.Valid {
		return nil
	}
	s := strings.TrimSpace(n.String)
	if s == "" {
		return nil
	}
	return &s
}

func parseTimestamp(s string) (*time.Time, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, false
	}
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02 15:04:05",
		"2006-01-02T15:04:05",
	}
	for _, layout := range layouts {
		if t, err := time.Parse(layout, s); err == nil {
			return &t, true
		}
	}
	return nil, false
}

func (api *API) HandleReceiveData(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 10<<20))
	if err != nil {
		writeErr(w, http.StatusBadRequest, "failed to read body")
		return
	}
	defer r.Body.Close()

	// Bisa array atau object
	var batch []MeasurementInput
	if err := json.Unmarshal(body, &batch); err != nil {
		var one MeasurementInput
		if err2 := json.Unmarshal(body, &one); err2 != nil {
			writeErr(w, http.StatusBadRequest, "invalid JSON payload (expect object or array)")
			return
		}
		batch = []MeasurementInput{one}
	}

	if len(batch) == 0 {
		writeErr(w, http.StatusBadRequest, "Empty payload")
		return
	}

	ctx := r.Context()

	// Normalisasi & enrich
	for i := range batch {
		// fallback user
		if strings.TrimSpace(batch[i].User) == "" {
			batch[i].User = batch[i].Username
		}

		// reverse geocode jika ada koordinat dan location_name belum ada
		if strings.TrimSpace(batch[i].LocationName) == "" &&
			batch[i].Location.Latitude != nil && batch[i].Location.Longitude != nil {

			place, err := api.getPlaceName(ctx, *batch[i].Location.Latitude, *batch[i].Location.Longitude)
			if err == nil && strings.TrimSpace(place) != "" {
				batch[i].LocationName = place
			}
		}

		// trim note biar rapi
		if batch[i].Note != nil {
			t := strings.TrimSpace(*batch[i].Note)
			if t == "" {
				batch[i].Note = nil
			} else {
				batch[i].Note = &t
			}
		}
	}

	received, err := api.insertMeasurements(ctx, batch)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"status":   "success",
		"received": received,
	})
}

func (api *API) insertMeasurements(ctx context.Context, batch []MeasurementInput) (int, error) {
	tx, err := api.db.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	
	q := `
		INSERT INTO measurements
			(user_name, timestamp_text, timestamp_ts, n, p, k, ph, ec, temp, hum, latitude, longitude, location_name, note)
		VALUES
			($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
	`

	count := 0
	for _, m := range batch {
		// timestamp_text: simpan persis string dari device/app
		tsText := strOrNil(m.Timestamp)

		// timestamp_ts: hasil parse (untuk sorting)
		tsParsed, ok := parseTimestamp(m.Timestamp)
		var tsAny any
		if ok && tsParsed != nil {
			tsAny = *tsParsed
		} else {
			tsAny = nil
		}

		_, err := tx.Exec(ctx, q,
			strOrNil(m.User), // $1 user_name
			tsText,           // $2 timestamp_text
			tsAny,            // $3 timestamp_ts
			m.N, m.P, m.K,    // $4..$6
			m.Ph, m.Ec, m.Temp, m.Hum, // $7..$10
			m.Location.Latitude,      // $11
			m.Location.Longitude,     // $12
			strOrNil(m.LocationName), // $13
			m.Note,                   // $14 ✅ note
		)
		if err != nil {
			return 0, err
		}
		count++
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, err
	}
	return count, nil
}

func (api *API) HandleDashboard(w http.ResponseWriter, r *http.Request) {
	list, err := api.fetchMeasurements(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}

	var latest *Measurement
	if len(list) > 0 {
		tmp := list[0]
		latest = &tmp
	}

	writeJSON(w, http.StatusOK, DashboardResponse{
		TotalCount: len(list),
		Latest:     latest,
		DataList:   list,
	})
}

func (api *API) HandleMeasurementsList(w http.ResponseWriter, r *http.Request) {
	list, err := api.fetchMeasurements(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, list)
}

func (api *API) HandleMeasurementDetail(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	m, err := api.fetchMeasurementByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeErr(w, http.StatusNotFound, "Data not found")
			return
		}
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, m)
}

func (api *API) fetchMeasurements(ctx context.Context) ([]Measurement, error) {
	rows, err := api.db.Query(ctx, `
		SELECT
			id::text,
			user_name,
			n, p, k,
			ph, ec, temp, hum,
			latitude, longitude,
			location_name,
			timestamp_text,
			timestamp_ts,
			created_at,
			note
		FROM measurements
		ORDER BY COALESCE(timestamp_ts, created_at) DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Measurement{}
	for rows.Next() {
		var (
			id        string
			user      sql.NullString
			n         sql.NullFloat64
			p         sql.NullFloat64
			k         sql.NullFloat64
			ph        sql.NullFloat64
			ec        sql.NullFloat64
			temp      sql.NullFloat64
			hum       sql.NullFloat64
			lat       sql.NullFloat64
			lon       sql.NullFloat64
			locName   sql.NullString
			tsText    sql.NullString
			tsParsed  sql.NullTime
			createdAt time.Time
			note      sql.NullString
		)

		if err := rows.Scan(
			&id,
			&user,
			&n, &p, &k,
			&ph, &ec, &temp, &hum,
			&lat, &lon,
			&locName,
			&tsText,
			&tsParsed,
			&createdAt,
			&note,
		); err != nil {
			return nil, err
		}

		// timestamp display
		displayTS := ""
		if tsText.Valid && strings.TrimSpace(tsText.String) != "" {
			displayTS = tsText.String
		} else if tsParsed.Valid {
			displayTS = tsParsed.Time.Format(time.RFC3339)
		} else {
			displayTS = createdAt.Format(time.RFC3339)
		}

		m := Measurement{
			ID:        id,
			User:      strings.TrimSpace(user.String),
			Timestamp: displayTS,
			N:         floatPtr(n),
			P:         floatPtr(p),
			K:         floatPtr(k),
			Ph:        floatPtr(ph),
			Ec:        floatPtr(ec),
			Temp:      floatPtr(temp),
			Hum:       floatPtr(hum),
			Location: Location{
				Latitude:  floatPtr(lat),
				Longitude: floatPtr(lon),
			},
			LocationName: strings.TrimSpace(locName.String),
			Note:         strPtr(note), // ✅ kirim note ke web
		}

		out = append(out, m)
	}

	return out, rows.Err()
}

func (api *API) fetchMeasurementByID(ctx context.Context, id string) (Measurement, error) {
	row := api.db.QueryRow(ctx, `
		SELECT
			id::text,
			user_name,
			n, p, k,
			ph, ec, temp, hum,
			latitude, longitude,
			location_name,
			timestamp_text,
			timestamp_ts,
			created_at,
			note
		FROM measurements
		WHERE id = $1
	`, id)

	var (
		uid       string
		user      sql.NullString
		n         sql.NullFloat64
		p         sql.NullFloat64
		k         sql.NullFloat64
		ph        sql.NullFloat64
		ec        sql.NullFloat64
		temp      sql.NullFloat64
		hum       sql.NullFloat64
		lat       sql.NullFloat64
		lon       sql.NullFloat64
		locName   sql.NullString
		tsText    sql.NullString
		tsParsed  sql.NullTime
		createdAt time.Time
		note      sql.NullString
	)

	if err := row.Scan(
		&uid,
		&user,
		&n, &p, &k,
		&ph, &ec, &temp, &hum,
		&lat, &lon,
		&locName,
		&tsText,
		&tsParsed,
		&createdAt,
		&note,
	); err != nil {
		return Measurement{}, err
	}

	displayTS := ""
	if tsText.Valid && strings.TrimSpace(tsText.String) != "" {
		displayTS = tsText.String
	} else if tsParsed.Valid {
		displayTS = tsParsed.Time.Format(time.RFC3339)
	} else {
		displayTS = createdAt.Format(time.RFC3339)
	}

	return Measurement{
		ID:        uid,
		User:      strings.TrimSpace(user.String),
		Timestamp: displayTS,
		N:         floatPtr(n),
		P:         floatPtr(p),
		K:         floatPtr(k),
		Ph:        floatPtr(ph),
		Ec:        floatPtr(ec),
		Temp:      floatPtr(temp),
		Hum:       floatPtr(hum),
		Location: Location{
			Latitude:  floatPtr(lat),
			Longitude: floatPtr(lon),
		},
		LocationName: strings.TrimSpace(locName.String),
		Note:         strPtr(note), // ✅ detail juga ada note
	}, nil
}
