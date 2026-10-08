#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Base64 of "id=GTM-TEST123&env=1&auth=dGVzdA", the shape of a real container config.
CONFIG=aWQ9R1RNLVRFU1QxMjMmZW52PTEmYXV0aD1kR1Z6ZEE=

setup() {
  WORK=$(mktemp -d)
  export TAGDOCK_CONFIG=$WORK/tagdock.env
  export TAGDOCK_SITES_DIR=$WORK/sites
  export TAGDOCK_OUT_DIR=$WORK/out
  mkdir -p "$TAGDOCK_SITES_DIR"
  TAGDOCK=$BATS_TEST_DIRNAME/../tagdock

  # Stand-ins for getent and ip, so the DNS check sees a server with address
  # 192.0.2.10 where every example.com name points to that address, unless a
  # test lists other answers in $WORK/dns.
  mkdir -p "$WORK/bin"
  cat >"$WORK/bin/getent" <<'EOF'
#!/usr/bin/env bash
answer=$(grep -m1 "^$2 " "$WORK/dns" 2>/dev/null | cut -d' ' -f2-)
if [[ -z $answer && $2 == *.example.com ]]; then
  answer=192.0.2.10
fi
[[ $answer == none ]] && exit 2
for address in $answer; do
  printf '%s STREAM %s
' "$address" "$2"
done
EOF
  cat >"$WORK/bin/ip" <<'EOF'
#!/usr/bin/env bash
printf '2: eth0    inet 192.0.2.10/24 brd 192.0.2.255 scope global eth0
'
EOF
  chmod +x "$WORK/bin/getent" "$WORK/bin/ip"
  export WORK
  export PATH=$WORK/bin:$PATH
}

teardown() {
  rm -rf "$WORK"
}

write_config() {
  printf '%s\n' "$@" >"$TAGDOCK_CONFIG"
}

write_site() {
  local name=$1
  shift
  printf '%s\n' "$@" >"$TAGDOCK_SITES_DIR/$name.env"
}

caddy_site() {
  write_site "$1" "CONTAINER_CONFIG=$CONFIG" "TAGGING_DOMAIN=$2" "PREVIEW_DOMAIN=$3"
}

@test "check prints the container id and domains of a caddy site" {
  write_config PROXY=caddy
  caddy_site shop sgtm.example.com preview.example.com

  run "$TAGDOCK" check

  [ "$status" -eq 0 ]
  [ "$output" = "shop: GTM-TEST123, tagging https://sgtm.example.com, preview https://preview.example.com" ]
}

@test "render writes a compose file with a preview and a tagging service per site" {
  write_config PROXY=caddy ACME_EMAIL=ops@example.com
  caddy_site shop sgtm.example.com preview.example.com

  run "$TAGDOCK" render

  [ "$status" -eq 0 ]
  grep -q '^name: tagdock$' "$TAGDOCK_OUT_DIR/compose.yaml"
  grep -q '^  shop-preview:$' "$TAGDOCK_OUT_DIR/compose.yaml"
  grep -q '^  shop-tagging:$' "$TAGDOCK_OUT_DIR/compose.yaml"
  grep -q 'RUN_AS_PREVIEW_SERVER: "true"' "$TAGDOCK_OUT_DIR/compose.yaml"
  grep -q 'PREVIEW_SERVER_URL: https://preview.example.com' "$TAGDOCK_OUT_DIR/compose.yaml"
  grep -q '^  caddy:$' "$TAGDOCK_OUT_DIR/compose.yaml"
  grep -q '"80:80"' "$TAGDOCK_OUT_DIR/compose.yaml"
}

@test "render writes a Caddyfile that routes each domain to its container" {
  write_config PROXY=caddy ACME_EMAIL=ops@example.com
  caddy_site shop sgtm.example.com preview.example.com

  run "$TAGDOCK" render

  [ "$status" -eq 0 ]
  grep -q $'^\temail ops@example.com$' "$TAGDOCK_OUT_DIR/Caddyfile"
  grep -A1 '^sgtm.example.com {$' "$TAGDOCK_OUT_DIR/Caddyfile" | grep -q 'reverse_proxy shop-tagging:8080'
  grep -A1 '^preview.example.com {$' "$TAGDOCK_OUT_DIR/Caddyfile" | grep -q 'reverse_proxy shop-preview:8080'
  run ! grep -q 'local_certs' "$TAGDOCK_OUT_DIR/Caddyfile"
}

@test "render keeps the container config out of the generated files" {
  write_config PROXY=caddy
  caddy_site shop sgtm.example.com preview.example.com

  run "$TAGDOCK" render

  [ "$status" -eq 0 ]
  grep -q "$TAGDOCK_SITES_DIR/shop.env" "$TAGDOCK_OUT_DIR/compose.yaml"
  run ! grep -rq "$CONFIG" "$TAGDOCK_OUT_DIR"
}

@test "render with PROXY=none publishes ports on 127.0.0.1 and has no caddy" {
  write_config PROXY=none
  write_site shop "CONTAINER_CONFIG=$CONFIG" PREVIEW_DOMAIN=preview.example.com TAGGING_PORT=18080 PREVIEW_PORT=18081

  run "$TAGDOCK" render

  [ "$status" -eq 0 ]
  grep -q '"127.0.0.1:18080:8080"' "$TAGDOCK_OUT_DIR/compose.yaml"
  grep -q '"127.0.0.1:18081:8080"' "$TAGDOCK_OUT_DIR/compose.yaml"
  run ! grep -q 'caddy' "$TAGDOCK_OUT_DIR/compose.yaml"
  [ ! -e "$TAGDOCK_OUT_DIR/Caddyfile" ]
}

@test "LISTEN_ADDRESS and custom ports are used for caddy" {
  write_config PROXY=caddy LISTEN_ADDRESS=127.0.0.1 HTTP_PORT=18880 HTTPS_PORT=18443 CADDY_LOCAL_CERTS=true
  caddy_site shop sgtm.example.com preview.example.com

  run "$TAGDOCK" render

  [ "$status" -eq 0 ]
  grep -q '"127.0.0.1:18880:80"' "$TAGDOCK_OUT_DIR/compose.yaml"
  grep -q '"127.0.0.1:18443:443/udp"' "$TAGDOCK_OUT_DIR/compose.yaml"
  grep -q $'^\tlocal_certs$' "$TAGDOCK_OUT_DIR/Caddyfile"
}

@test "values may be quoted and files may use CRLF line endings" {
  write_config 'PROXY="caddy"'
  printf 'CONTAINER_CONFIG="%s"\r\nTAGGING_DOMAIN=sgtm.example.com\r\nPREVIEW_DOMAIN='"'"'preview.example.com'"'"'\r\n' "$CONFIG" >"$TAGDOCK_SITES_DIR/shop.env"

  run "$TAGDOCK" check

  [ "$status" -eq 0 ]
  [[ $output == *"GTM-TEST123"* ]]
}

@test "a config that is not a server container config is rejected" {
  write_config PROXY=caddy
  write_site shop CONTAINER_CONFIG=not-a-config TAGGING_DOMAIN=sgtm.example.com PREVIEW_DOMAIN=preview.example.com

  run "$TAGDOCK" check

  [ "$status" -eq 1 ]
  [[ $output == *"CONTAINER_CONFIG is not a server container config"* ]]
}

@test "a missing tagging domain is rejected with PROXY=caddy" {
  write_config PROXY=caddy
  write_site shop "CONTAINER_CONFIG=$CONFIG" PREVIEW_DOMAIN=preview.example.com

  run "$TAGDOCK" check

  [ "$status" -eq 1 ]
  [[ $output == *"TAGGING_DOMAIN is empty"* ]]
}

@test "the same domain on two sites is rejected" {
  write_config PROXY=caddy
  caddy_site one sgtm.example.com preview.example.com
  caddy_site two other.example.com preview.example.com

  run "$TAGDOCK" check

  [ "$status" -eq 1 ]
  [[ $output == *"preview.example.com is used by more than one site"* ]]
}

@test "the same port on two sites is rejected with PROXY=none" {
  write_config PROXY=none
  write_site one "CONTAINER_CONFIG=$CONFIG" PREVIEW_DOMAIN=p1.example.com TAGGING_PORT=18080 PREVIEW_PORT=18081
  write_site two "CONTAINER_CONFIG=$CONFIG" PREVIEW_DOMAIN=p2.example.com TAGGING_PORT=18082 PREVIEW_PORT=18080

  run "$TAGDOCK" check

  [ "$status" -eq 1 ]
  [[ $output == *"port 18080 is used more than once"* ]]
}

@test "an unknown PROXY value is rejected" {
  write_config PROXY=traefik
  caddy_site shop sgtm.example.com preview.example.com

  run "$TAGDOCK" check

  [ "$status" -eq 1 ]
  [[ $output == *"PROXY must be caddy or none"* ]]
}

@test "a line that is not KEY=VALUE is rejected with its line number" {
  write_config PROXY=caddy 'export FOO=bar'
  caddy_site shop sgtm.example.com preview.example.com

  run "$TAGDOCK" check

  [ "$status" -eq 1 ]
  [[ $output == *"tagdock.env:2: expected KEY=VALUE"* ]]
}

@test "values are not executed" {
  # shellcheck disable=SC2016 # the value must reach tagdock unexpanded
  write_config PROXY=caddy 'ACME_EMAIL=$(touch '"$WORK"'/executed)'
  caddy_site shop sgtm.example.com preview.example.com

  run "$TAGDOCK" render

  [ ! -e "$WORK/executed" ]
}

@test "check fails when there are no sites" {
  write_config PROXY=caddy

  run "$TAGDOCK" check

  [ "$status" -eq 1 ]
  [[ $output == *"no sites found"* ]]
}

@test "add --template copies the template into a file only the owner can read" {
  write_config PROXY=caddy

  run "$TAGDOCK" add shop --template

  [ "$status" -eq 0 ]
  cmp -s "$BATS_TEST_DIRNAME/../sites/example.env.template" "$TAGDOCK_SITES_DIR/shop.env"
  [ "$(stat -c %a "$TAGDOCK_SITES_DIR/shop.env")" = "600" ]
}

@test "add asks for the config and domains and writes them into the site file" {
  write_config PROXY=caddy

  run "$TAGDOCK" add shop <<<"$CONFIG"$'
''https://SGTM.example.com/'$'
''sgtm-preview.example.com'

  [ "$status" -eq 0 ]
  [[ $output == *"Server container GTM-TEST123"* ]]
  grep -qx "CONTAINER_CONFIG=$CONFIG" "$TAGDOCK_SITES_DIR/shop.env"
  grep -qx 'TAGGING_DOMAIN=sgtm.example.com' "$TAGDOCK_SITES_DIR/shop.env"
  grep -qx 'PREVIEW_DOMAIN=sgtm-preview.example.com' "$TAGDOCK_SITES_DIR/shop.env"
  grep -qx 'TAGGING_MEMORY=1g' "$TAGDOCK_SITES_DIR/shop.env"
  [ "$(stat -c %a "$TAGDOCK_SITES_DIR/shop.env")" = "600" ]
  run "$TAGDOCK" check
  [ "$status" -eq 0 ]
}

@test "add asks again after an invalid config, domain or repeated domain" {
  write_config PROXY=caddy

  run "$TAGDOCK" add shop <<<"not-a-config"$'
'"$CONFIG"$'
''not a domain'$'
''sgtm.example.com'$'
''sgtm.example.com'$'
''sgtm-preview.example.com'

  [ "$status" -eq 0 ]
  [[ $output == *"this is not a server container config"* ]]
  [[ $output == *"'not a domain' is not a valid domain"* ]]
  [[ $output == *"sgtm.example.com is already used"* ]]
  grep -qx 'PREVIEW_DOMAIN=sgtm-preview.example.com' "$TAGDOCK_SITES_DIR/shop.env"
}

@test "add rejects a domain or port that another site uses" {
  write_config PROXY=none
  write_site one "CONTAINER_CONFIG=$CONFIG" PREVIEW_DOMAIN=p1.example.com TAGGING_PORT=18080 PREVIEW_PORT=18081

  run "$TAGDOCK" add two <<<"$CONFIG"$'
''p1.example.com'$'
''p2.example.com'$'
''18081'$'
''18082'$'
''18082'$'
''18083'

  [ "$status" -eq 0 ]
  [[ $output == *"p1.example.com is already used"* ]]
  [[ $output == *"port 18081 is already used"* ]]
  [[ $output == *"port 18082 is already used"* ]]
  grep -qx 'TAGGING_PORT=18082' "$TAGDOCK_SITES_DIR/two.env"
  grep -qx 'PREVIEW_PORT=18083' "$TAGDOCK_SITES_DIR/two.env"
  run "$TAGDOCK" check
  [ "$status" -eq 0 ]
}

@test "add stops without writing a file when the answers run out" {
  write_config PROXY=caddy

  run "$TAGDOCK" add shop <<<"$CONFIG"

  [ "$status" -eq 1 ]
  [[ $output == *"--template"* ]]
  [ ! -e "$TAGDOCK_SITES_DIR/shop.env" ]
}

@test "check warns about a domain that does not resolve but still succeeds" {
  write_config PROXY=caddy
  caddy_site shop sgtm.example.com preview.example.com
  printf 'preview.example.com none
' >"$WORK/dns"

  run "$TAGDOCK" check

  [ "$status" -eq 0 ]
  [[ $output == *"warning: preview.example.com does not resolve"* ]]
  [[ $output != *"sgtm.example.com does not resolve"* ]]
}

@test "check warns about a domain that points to another server" {
  write_config PROXY=caddy
  caddy_site shop sgtm.example.com preview.example.com
  printf 'sgtm.example.com 203.0.113.5 203.0.113.6
' >"$WORK/dns"

  run "$TAGDOCK" check

  [ "$status" -eq 0 ]
  [[ $output == *"warning: sgtm.example.com points to 203.0.113.5 203.0.113.6, which is not an address of this server"* ]]
  [[ $output != *"preview.example.com points to"* ]]
}

@test "check does not warn when a domain points to one of the server addresses" {
  write_config PROXY=caddy
  caddy_site shop sgtm.example.com preview.example.com
  printf 'sgtm.example.com 203.0.113.5 192.0.2.10
' >"$WORK/dns"

  run "$TAGDOCK" check

  [ "$status" -eq 0 ]
  [[ $output != *"warning"* ]]
}

@test "with PROXY=none only the preview domain is checked" {
  write_config PROXY=none
  write_site shop "CONTAINER_CONFIG=$CONFIG" TAGGING_DOMAIN=sgtm.example.com PREVIEW_DOMAIN=preview.example.com TAGGING_PORT=18080 PREVIEW_PORT=18081
  printf 'sgtm.example.com none
preview.example.com none
' >"$WORK/dns"

  run "$TAGDOCK" check

  [ "$status" -eq 0 ]
  [[ $output == *"preview.example.com does not resolve"* ]]
  [[ $output != *"sgtm.example.com does not resolve"* ]]
}

@test "add refuses an existing site and an invalid name" {
  write_config PROXY=caddy
  caddy_site shop sgtm.example.com preview.example.com

  run "$TAGDOCK" add shop
  [ "$status" -eq 1 ]
  [[ $output == *"already exists"* ]]

  run "$TAGDOCK" add Shop_1
  [ "$status" -eq 1 ]
  [[ $output == *"site names may only contain"* ]]
}
