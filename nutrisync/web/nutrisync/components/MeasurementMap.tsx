"use client";

import { useEffect, useRef } from "react";
import type { Measurement } from "@/lib/types";
import { getMeasurementId } from "@/lib/types";

type Props = {
  points: Measurement[];
  className?: string;
};

function escapeHtml(input: string) {
  return input
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function hasCoord(m: Measurement) {
  return (
    typeof m.location?.latitude === "number" &&
    typeof m.location?.longitude === "number"
  );
}

export default function MeasurementMap({ points, className }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);

  const mapRef = useRef<any>(null);
  const layerRef = useRef<any>(null);
  const LRef = useRef<any>(null);

  // Init map sekali saja (mount/unmount)
  useEffect(() => {
    let cancelled = false;

    (async () => {
      const leaflet = await import("leaflet");
      const L = leaflet.default;
      LRef.current = L;

      if (cancelled || !containerRef.current) return;

      // Fix icon Leaflet (biar marker tampil di Next)
      delete (L.Icon.Default.prototype as any)._getIconUrl;
      L.Icon.Default.mergeOptions({
        iconRetinaUrl:
          "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
        iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
        shadowUrl:
          "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
      });

      const first = points.find(hasCoord);
      const defaultLat = first?.location?.latitude ?? -2.5;
      const defaultLon = first?.location?.longitude ?? 118.0;
      const zoom = first ? 8 : 5;

      const map = L.map(containerRef.current).setView(
        [defaultLat, defaultLon],
        zoom
      );

      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: "&copy; OpenStreetMap contributors",
      }).addTo(map);

      mapRef.current = map;
      layerRef.current = L.layerGroup().addTo(map);

      // Hindari blank saat container baru muncul
      setTimeout(() => {
        map.invalidateSize();
      }, 0);
    })();

    return () => {
      cancelled = true;
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
      layerRef.current = null;
      LRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ResizeObserver agar map tetap “pas” saat layout berubah
  useEffect(() => {
    if (!containerRef.current) return;
    if (typeof ResizeObserver === "undefined") return;

    const obs = new ResizeObserver(() => {
      if (mapRef.current) mapRef.current.invalidateSize();
    });

    obs.observe(containerRef.current);
    return () => obs.disconnect();
  }, []);

  // Update markers setiap points berubah (tanpa destroy map)
  useEffect(() => {
    const L = LRef.current;
    if (!L || !mapRef.current || !layerRef.current) return;

    layerRef.current.clearLayers();

    const markers: any[] = [];

    for (const item of points) {
      if (!hasCoord(item)) continue;

      const lat = item.location!.latitude as number;
      const lon = item.location!.longitude as number;

      const safeLoc = escapeHtml(item.location_name || "Lokasi tidak diketahui");
      const safeTime = escapeHtml(item.timestamp || "");
      const safeNote = item.note?.trim() ? escapeHtml(item.note) : "";
      const id = getMeasurementId(item);
      const safeId = escapeHtml(id);
      const detailUrl = id ? `/detail/${encodeURIComponent(id)}` : "";

      const popupHtml = `
        <strong>${safeLoc}</strong><br/>
        <small>${safeTime}</small><br/>
        <div style="margin-top:6px;">
          N: ${item.n ?? "N/A"} | P: ${item.p ?? "N/A"} | K: ${item.k ?? "N/A"}
        </div>
        ${
          safeNote
            ? `<div style="margin-top:6px;"><em>${safeNote}</em></div>`
            : ""
        }
        ${
          safeId
            ? `<div style="margin-top:6px;"><small>ID: ${safeId}</small></div>`
            : ""
        }
        <div style="margin-top:8px; display:flex; gap:10px; flex-wrap:wrap;">
          <a href="https://www.google.com/maps?q=${lat},${lon}" target="_blank" rel="noreferrer">Google Maps</a>
          ${
            detailUrl
              ? `<a href="${detailUrl}" rel="noreferrer">Detail</a>`
              : ""
          }
        </div>
      `;

      const m = L.marker([lat, lon]).bindPopup(popupHtml);
      m.addTo(layerRef.current);
      markers.push(m);
    }

    // Auto fit bounds
    if (markers.length > 1) {
      const group = L.featureGroup(markers);
      mapRef.current.fitBounds(group.getBounds().pad(0.2));
    } else if (markers.length === 1) {
      const ll = markers[0].getLatLng();
      mapRef.current.setView([ll.lat, ll.lng], 12);
    }
  }, [points]);

  return (
    <div
      ref={containerRef}
      className={["map", className].filter(Boolean).join(" ")}
    />
  );
}
