package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
)

type nominatimReverseResp struct {
	DisplayName string `json:"display_name"`
}

func (api *API) getPlaceName(ctx context.Context, lat, lon float64) (string, error) {
	base := "https://nominatim.openstreetmap.org/reverse"

	q := url.Values{}
	q.Set("format", "jsonv2")
	q.Set("lat", fmt.Sprintf("%f", lat))
	q.Set("lon", fmt.Sprintf("%f", lon))

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, base+"?"+q.Encode(), nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", api.nominatimUserAgent)

	resp, err := api.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("nominatim status %d", resp.StatusCode)
	}

	var out nominatimReverseResp
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", err
	}
	return out.DisplayName, nil
}
