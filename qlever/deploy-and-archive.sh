#!/usr/bin/env bash
set -eu

REPO=/home/semantic/cimple/knowledge-base
DUMPS="$REPO/qlever/dumps"
CACHE="$REPO/webhookd/cache/claim-review.nt"
CLAIMREVIEW="$DUMPS/graph/claimreview/claim-review.nt"
ARCHIVE_DIR=/var/www/data.cimple.eu/dumps
ARCHIVE="$ARCHIVE_DIR/cimple-kg-latest.tar.gz"
COUNT_STATE="$REPO/qlever/.index-triple-count"
LOG_FILE="$REPO/qlever/deploy.log"
QLEVER_ENDPOINT=http://127.0.0.1:7019
MIN_TOTAL=15000000

cd "$REPO"

if [ -f "$REPO/.env" ]; then
  set -a
  . "$REPO/.env"
  set +a
fi

exec >> "$LOG_FILE" 2>&1
echo "[$(date '+%F %T')] === deploy-and-archive starting ==="

fail() {
  echo "[$(date '+%F %T')] FAILED: $1"
  if [ -n "${HEALTHCHECKS_PING_URL}" ]; then
    curl -fsS -m 10 --retry 5 "${HEALTHCHECKS_PING_URL}/fail" || true
  fi
  exit 1
}

ping_start() {
  if [ -n "${HEALTHCHECKS_PING_URL}" ]; then
    curl -fsS -m 10 --retry 5 "${HEALTHCHECKS_PING_URL}/start" || true
  fi
}

compose() {
  docker compose -f "$REPO/compose.yml" "$@"
}

volume_admin() {
  compose --profile qlever-init run --rm --no-deps qlever-volume-admin sh -eu -c "$1"
}

volume_admin '
  if [ ! -d /data/index-current ] && [ -d /data/index-previous ]; then
    mv /data/index-previous /data/index-current
    echo "recovered missing index-current from index-previous"
  fi
' || true

wait_for_qlever() {
  local attempts=0
  while [ "$attempts" -lt 60 ]; do
    if compose exec -T qlever curl -fsS -G \
        -H 'Accept: application/sparql-results+json' \
        --data-urlencode 'query=ASK { ?s ?p ?o }' \
        http://localhost:7019 >/dev/null 2>&1; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 2
  done
  return 1
}

count_triples() {
  curl -fsS -m 120 -G "$QLEVER_ENDPOINT" \
    -H 'Accept: application/sparql-results+json' \
    --data-urlencode 'query=SELECT (COUNT(*) AS ?c) WHERE { ?s ?p ?o }' \
  | jq -r '.results.bindings[0].c.value'
}

ping_start

echo "[$(date '+%F %T')] refreshing claim-review.nt from cache"
if [ ! -s "$CACHE" ]; then fail "cache file missing or empty: $CACHE"; fi
TMP=$(mktemp "$DUMPS/graph/claimreview/.refresh.XXXXXX")
awk '!seen[$0]++' "$CACHE" > "$TMP"
chmod 644 "$TMP"
mv "$TMP" "$CLAIMREVIEW"

echo "[$(date '+%F %T')] archiving dumps"
tar -czf "$ARCHIVE" -C "$DUMPS" .

echo "[$(date '+%F %T')] preparing /data/index-next"
set -a; source "$REPO/.env"; set +a
volume_admin "
  rm -rf /data/index-next
  mkdir -p /data/index-next
  chown -R ${QLEVER_UID:-999}:${QLEVER_GID:-999} /data/index-next
"
echo "[$(date '+%F %T')] building index (qlever-index container)"
QLEVER_DEPLOY_QLEVERFILE="$REPO/qlever/Qleverfile" \
  compose --profile qlever-init run --rm --no-deps qlever-index \
  || fail "index build failed"

echo "[$(date '+%F %T')] swapping index"
volume_admin '
  test -f /data/index-next/Qleverfile
  rm -rf /data/index-previous
  if [ -d /data/index-current ]; then
    mv /data/index-current /data/index-previous
  fi
  mv /data/index-next /data/index-current
'
compose stop qlever >/dev/null 2>&1 || true
compose up -d --force-recreate qlever

echo "[$(date '+%F %T')] waiting for QLever"
if ! wait_for_qlever; then
  compose logs --tail 100 qlever || true
  compose stop qlever >/dev/null 2>&1 || true
  if volume_admin 'test -d /data/index-previous' 2>/dev/null; then
    volume_admin '
      rm -rf /data/index-failed
      mv /data/index-current /data/index-failed
      mv /data/index-previous /data/index-current
      rm -rf /data/index-failed
    '
    compose up -d --force-recreate qlever
    fail "new index did not come up; previous index restored"
  else
    fail "new index did not come up; no previous index to restore (first deploy?)"
  fi
fi
TOTAL=$(count_triples) || fail "triple count query failed"
echo "[$(date '+%F %T')] total triples: $TOTAL"
if [ -f "$COUNT_STATE" ]; then
  PREV=$(cat "$COUNT_STATE")
  FLOOR=$(( PREV * 95 / 100 ))
  if [ "$TOTAL" -lt "$FLOOR" ]; then
    fail "triple count dropped: $TOTAL < 95% of previous $PREV"
  fi
fi
echo "$TOTAL" > "$COUNT_STATE"

GRAPH_STATE="$REPO/qlever/.index-graph-counts"
GRAPHS_OK=1
COUNTS_OUT="{}"
for g in afp birdwatch check-that claimreview dbpedia mediaeval propaganda semeval2024; do
  c=$(curl -fsS -m 120 -G "$QLEVER_ENDPOINT" \
    -H 'Accept: application/sparql-results+json' \
    --data-urlencode "query=SELECT (COUNT(*) AS ?c) WHERE { GRAPH <http://data.cimple.eu/graph/$g> { ?s ?p ?o } }" \
    | jq -r '.results.bindings[0].c.value') || { GRAPHS_OK=0; break; }
  COUNTS_OUT=$(jq --arg g "$g" --argjson c "$c" '. + {($g): $c}' <<<"$COUNTS_OUT")
  if [ -f "$GRAPH_STATE" ]; then
    prev=$(jq -r --arg g "$g" '.[$g] // 0' "$GRAPH_STATE")
    if [ "${prev:-0}" -gt 0 ] 2>/dev/null; then
      floor=$(( prev * 95 / 100 ))
      [ "${c:-0}" -ge "$floor" ] || { echo "graph $g dropped: $c < 95% of $prev"; GRAPHS_OK=0; }
    fi
  fi
done
[ "$GRAPHS_OK" -eq 1 ] || fail "per-graph count check failed"
echo "$COUNTS_OUT" > "$GRAPH_STATE"
echo "[$(date '+%F %T')] per-graph counts ok: $COUNTS_OUT"

if [ -n "${HEALTHCHECKS_PING_URL}" ]; then
  curl -fsS -m 10 --retry 5 "${HEALTHCHECKS_PING_URL}" || true
fi
echo "[$(date '+%F %T')] === deploy-and-archive done, serving $TOTAL triples ==="
