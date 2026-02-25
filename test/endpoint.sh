#!/bin/bash

VM="192.168.2.10"
BASE="http://$VM:30080"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
PASS=0
FAIL=0

print_header() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

assert_status() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo -e "  ${GREEN}✓ PASS${NC} $desc (HTTP $actual)"
    ((PASS++))
  else
    echo -e "  ${RED}✗ FAIL${NC} $desc (expected $expected, got $actual)"
    ((FAIL++))
  fi
}

assert_contains() {
  local desc="$1" expected="$2" body="$3"
  if echo "$body" | grep -q "$expected"; then
    echo -e "  ${GREEN}✓ PASS${NC} $desc"
    ((PASS++))
  else
    echo -e "  ${RED}✗ FAIL${NC} $desc (expected '$expected' in response)"
    ((FAIL++))
  fi
}

# ──────────────────────────────────────────────
print_header "1. HEALTH & HOME"
# ──────────────────────────────────────────────

echo -e "${YELLOW}► GET /${NC}"
resp=$(curl -s -w "\n%{http_code}" "$BASE/")
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -1)
assert_status "Home page returns 200" 200 "$code"
assert_contains "Response contains 'URL Shortener'" "URL Shortener" "$body"
echo "$body" | python3 -m json.tool 2>/dev/null

echo ""
echo -e "${YELLOW}► GET /health${NC}"
resp=$(curl -s -w "\n%{http_code}" "$BASE/health")
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -1)
assert_status "Health check returns 200" 200 "$code"
assert_contains "Response contains 'healthy'" "healthy" "$body"

# ──────────────────────────────────────────────
print_header "2. SHORTEN URLs"
# ──────────────────────────────────────────────

echo -e "${YELLOW}► POST /shorten (auto code)${NC}"
resp=$(curl -s -w "\n%{http_code}" -X POST "$BASE/shorten" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://github.com"}')
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -1)
assert_status "Shorten with auto code returns 201" 201 "$code"
assert_contains "Response contains short_url" "short_url" "$body"
AUTO_CODE=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin)['code'])" 2>/dev/null)
echo "    Generated code: $AUTO_CODE"

echo ""
echo -e "${YELLOW}► POST /shorten (custom code 'goog')${NC}"
resp=$(curl -s -w "\n%{http_code}" -X POST "$BASE/shorten" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://google.com", "custom_code": "goog"}')
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -1)
assert_status "Shorten with custom code returns 201" 201 "$code"
assert_contains "Response contains 'goog'" "goog" "$body"

echo ""
echo -e "${YELLOW}► POST /shorten (custom code 'k8s')${NC}"
resp=$(curl -s -w "\n%{http_code}" -X POST "$BASE/shorten" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://kubernetes.io", "custom_code": "k8s"}')
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -1)
assert_status "Shorten with custom code returns 201" 201 "$code"

# ──────────────────────────────────────────────
print_header "3. REDIRECT"
# ──────────────────────────────────────────────

echo -e "${YELLOW}► GET /goog (expect 302 redirect)${NC}"
code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/goog")
assert_status "Redirect returns 302" 302 "$code"

echo ""
echo -e "${YELLOW}► GET /goog -L (follow redirect)${NC}"
final_url=$(curl -s -o /dev/null -w "%{url_effective}" -L "$BASE/goog")
assert_contains "Redirects to google.com" "google.com" "$final_url"
echo "    Final URL: $final_url"

# ──────────────────────────────────────────────
print_header "4. STATS"
# ──────────────────────────────────────────────

echo -e "${YELLOW}► Clicking /goog 3 more times...${NC}"
curl -s -o /dev/null "$BASE/goog"
curl -s -o /dev/null "$BASE/goog"
curl -s -o /dev/null "$BASE/goog"

echo -e "${YELLOW}► GET /stats/goog${NC}"
resp=$(curl -s -w "\n%{http_code}" "$BASE/stats/goog")
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -1)
assert_status "Stats returns 200" 200 "$code"
assert_contains "Response contains clicks" "clicks" "$body"
echo "$body" | python3 -m json.tool 2>/dev/null

# ──────────────────────────────────────────────
print_header "5. LIST ALL"
# ──────────────────────────────────────────────

echo -e "${YELLOW}► GET /all${NC}"
resp=$(curl -s -w "\n%{http_code}" "$BASE/all")
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -1)
assert_status "List all returns 200" 200 "$code"
assert_contains "Response contains 'total'" "total" "$body"
echo "$body" | python3 -m json.tool 2>/dev/null

# ──────────────────────────────────────────────
print_header "6. ERROR HANDLING"
# ──────────────────────────────────────────────

echo -e "${YELLOW}► POST /shorten (missing url field)${NC}"
resp=$(curl -s -w "\n%{http_code}" -X POST "$BASE/shorten" \
  -H "Content-Type: application/json" \
  -d '{"wrong": "field"}')
code=$(echo "$resp" | tail -1)
assert_status "Missing field returns 400" 400 "$code"

echo ""
echo -e "${YELLOW}► POST /shorten (duplicate custom code 'goog')${NC}"
resp=$(curl -s -w "\n%{http_code}" -X POST "$BASE/shorten" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com", "custom_code": "goog"}')
code=$(echo "$resp" | tail -1)
assert_status "Duplicate code returns 409" 409 "$code"

echo ""
echo -e "${YELLOW}► GET /stats/doesnotexist${NC}"
resp=$(curl -s -w "\n%{http_code}" "$BASE/stats/doesnotexist")
code=$(echo "$resp" | tail -1)
assert_status "Non-existent stats returns 404" 404 "$code"

echo ""
echo -e "${YELLOW}► GET /nope (non-existent redirect)${NC}"
code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/nope")
assert_status "Non-existent redirect returns 404" 404 "$code"

# ──────────────────────────────────────────────
print_header "RESULTS"
# ──────────────────────────────────────────────

TOTAL=$((PASS + FAIL))
echo ""
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
echo -e "  Total:  $TOTAL"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}🎉 ALL TESTS PASSED!${NC}"
else
  echo -e "  ${RED}⚠  SOME TESTS FAILED${NC}"
fi
echo ""