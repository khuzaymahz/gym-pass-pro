"use client";

import "leaflet/dist/leaflet.css";

import type { Map as LMap, Marker as LMarker } from "leaflet";
import { useTranslations } from "next-intl";
import { useEffect, useRef, useState } from "react";

// Capital fallback so an empty form opens on Amman, not the ocean.
const AMMAN = { lat: 31.9539, lng: 35.9106 };

// Amber teardrop pin (brand) as a divIcon so we don't depend on Leaflet's
// default marker images, which break under bundlers.
const PIN_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="30" height="38" viewBox="0 0 24 30"><path d="M12 0C6.48 0 2 4.48 2 10c0 7.2 8.5 18.6 9.13 19.43a1.08 1.08 0 0 0 1.74 0C13.5 28.6 22 17.2 22 10 22 4.48 17.52 0 12 0z" fill="#F8BB0A" stroke="#0E0E0F" stroke-width="1.5"/><circle cx="12" cy="10" r="3.6" fill="#0E0E0F"/></svg>`;

type Picked = { lat: number; lng: number; area?: string };
type SearchHit = { display_name: string; lat: string; lon: string };

// Reverse-geocode a point to a human "area" (suburb/city/governorate),
// best-effort. Returns "" on any failure so the caller can ignore it.
async function reverseArea(lat: number, lng: number): Promise<string> {
  try {
    const r = await fetch(
      `https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=14&accept-language=ar,en&lat=${lat}&lon=${lng}`,
    );
    const j = await r.json();
    const a = j.address ?? {};
    return (
      a.suburb ||
      a.neighbourhood ||
      a.city_district ||
      a.city ||
      a.town ||
      a.village ||
      a.municipality ||
      a.county ||
      a.state ||
      ""
    );
  } catch {
    return "";
  }
}

export function LocationPicker({
  lat,
  lng,
  onPick,
}: {
  lat?: number | null;
  lng?: number | null;
  onPick: (p: Picked) => void;
}) {
  const t = useTranslations("join.map");
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<LMap | null>(null);
  const markerRef = useRef<LMarker | null>(null);
  // Keep the latest onPick without re-initialising the map.
  const onPickRef = useRef(onPick);
  onPickRef.current = onPick;
  // Set true right before we programmatically change `query`, so the
  // debounced search effect doesn't immediately re-search the chosen label.
  const skipSearch = useRef(false);

  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchHit[]>([]);
  const [searching, setSearching] = useState(false);

  // Commit a point: update the form immediately, then enrich with the area.
  const commit = (la: number, lo: number) => {
    onPickRef.current({ lat: la, lng: lo });
    void reverseArea(la, lo).then((area) => {
      if (area) onPickRef.current({ lat: la, lng: lo, area });
    });
  };

  // Initialise the Leaflet map once (client-only — Leaflet touches `window`).
  useEffect(() => {
    let cancelled = false;
    let map: LMap | undefined;
    void (async () => {
      const L = (await import("leaflet")).default;
      if (cancelled || !containerRef.current || mapRef.current) return;
      const start = lat != null && lng != null ? { lat, lng } : AMMAN;
      map = L.map(containerRef.current).setView(
        [start.lat, start.lng],
        lat != null ? 14 : 11,
      );
      L.tileLayer(
        "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png",
        {
          maxZoom: 19,
          attribution:
            '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',
        },
      ).addTo(map);
      const icon = L.divIcon({
        className: "",
        html: PIN_SVG,
        iconSize: [30, 38],
        iconAnchor: [15, 36],
      });
      const marker = L.marker([start.lat, start.lng], {
        draggable: true,
        icon,
      }).addTo(map);
      marker.on("dragend", () => {
        const p = marker.getLatLng();
        commit(p.lat, p.lng);
      });
      map.on("click", (e) => {
        marker.setLatLng(e.latlng);
        commit(e.latlng.lat, e.latlng.lng);
      });
      mapRef.current = map;
      markerRef.current = marker;
      // The container may have sized after init (grid/flex); re-measure.
      setTimeout(() => map?.invalidateSize(), 0);
    })();
    return () => {
      cancelled = true;
      map?.remove();
      mapRef.current = null;
      markerRef.current = null;
    };
    // Init-once: subsequent lat/lng changes are handled by the effect below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Reflect external lat/lng edits (e.g. the manual inputs) onto the marker.
  useEffect(() => {
    if (mapRef.current && markerRef.current && lat != null && lng != null) {
      markerRef.current.setLatLng([lat, lng]);
    }
  }, [lat, lng]);

  // Debounced address search (Nominatim, Jordan-scoped).
  useEffect(() => {
    if (skipSearch.current) {
      skipSearch.current = false;
      return;
    }
    const q = query.trim();
    if (q.length < 3) {
      setResults([]);
      return;
    }
    const id = setTimeout(async () => {
      setSearching(true);
      try {
        const r = await fetch(
          `https://nominatim.openstreetmap.org/search?format=jsonv2&countrycodes=jo&limit=6&accept-language=ar,en&q=${encodeURIComponent(q)}`,
        );
        setResults((await r.json()) as SearchHit[]);
      } catch {
        setResults([]);
      } finally {
        setSearching(false);
      }
    }, 600);
    return () => clearTimeout(id);
  }, [query]);

  const choose = (hit: SearchHit) => {
    const la = Number.parseFloat(hit.lat);
    const lo = Number.parseFloat(hit.lon);
    mapRef.current?.setView([la, lo], 15);
    markerRef.current?.setLatLng([la, lo]);
    commit(la, lo);
    skipSearch.current = true;
    setQuery(hit.display_name);
    setResults([]);
  };

  return (
    <div className="flex flex-col gap-2">
      <div className="relative">
        <input
          type="search"
          className="input input-sm w-full"
          placeholder={t("searchPlaceholder")}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          // Don't submit the parent gym form when searching with Enter.
          onKeyDown={(e) => e.key === "Enter" && e.preventDefault()}
        />
        {searching ? (
          <span className="pointer-events-none absolute end-2 top-1/2 -translate-y-1/2 text-[11px] text-muted">
            {t("searching")}
          </span>
        ) : null}
        {results.length > 0 ? (
          <ul className="absolute z-[1100] mt-1 max-h-56 w-full overflow-auto rounded-md border border-line bg-surface shadow-lg">
            {results.map((r, i) => (
              <li key={`${r.lat}-${r.lon}-${i}`}>
                <button
                  type="button"
                  onClick={() => choose(r)}
                  className="block w-full truncate px-3 py-2 text-start text-[12.5px] text-paper hover:bg-ink"
                >
                  {r.display_name}
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </div>
      <div
        ref={containerRef}
        className="h-72 w-full overflow-hidden rounded-md border border-line"
        style={{ zIndex: 0 }}
      />
      <p className="text-[11px] text-muted">{t("hint")}</p>
    </div>
  );
}
