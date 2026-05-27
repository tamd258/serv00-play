#!/bin/sh
set -eu
APP_NAME="abcd"
APP_ROOT="${APP_ROOT:-$HOME/abcd}"
SRC_DIR="$APP_ROOT/src"
DATA_DIR="$APP_ROOT/data"
BIN="$APP_ROOT/abcd"
INSTALLER_DIR="$HOME/serv00-abcd"
SOURCE_REPO="${ABCD_SOURCE_REPO:-https://github.com/tamd258/alist.git}"
WEB_DIST_URL="${ABCD_WEB_DIST_URL:-https://github.com/AlistGo/alist-web/releases/latest/download/dist.tar.gz}"
DEFAULT_ADMIN_PASSWORD="${ABCD_ADMIN_PASSWORD:-Abcd123!}"
RAW_BASE="${ABCD_RAW_BASE:-https://raw.githubusercontent.com/tamd258/serv00-play/main}"
red(){ printf '\033[0;91m%s\033[0m\n' "$1"; }
green(){ printf '\033[0;92m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[0;33m%s\033[0m\n' "$1"; }
need(){ command -v "$1" >/dev/null 2>&1 || { red "缺少命令: $1"; exit 1; }; }
ensure_binexec(){ devil binexec on >/dev/null 2>&1 || true; }
reserve_port(){
  if [ -f "$APP_ROOT/port" ]; then cat "$APP_ROOT/port"; return; fi
  out="$(devil port add tcp random abcd 2>&1 || true)"
  port="$(devil port list | awk '$2=="tcp" && $3=="abcd" {print $1; exit}')"
  [ -z "$port" ] && port="$(printf '%s\n' "$out" | awk '/[0-9]+/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/) print $i}' | head -1)"
  [ -z "$port" ] && { red "端口申请失败: $out"; exit 1; }
  mkdir -p "$APP_ROOT"
  printf '%s' "$port" > "$APP_ROOT/port"
  printf '%s\n' "$port"
}
make_proxy_domain(){
  port="$1"
  printf '请输入域名前缀或完整域名 [abcd]: '
  read domain_input || true
  domain_input="${domain_input:-abcd}"
  case "$domain_input" in
    *.*) domain="$domain_input" ;;
    *) domain="${domain_input}.$(whoami).serv00.net" ;;
  esac
  resp="$(devil www add "$domain" proxy localhost "$port" 2>&1 || true)"
  printf '%s\n' "$resp"
  if ! printf '%s' "$resp" | grep -Eiq 'succesfully|successfully|Ok|already exists'; then
    red "绑定域名失败: $domain"
    exit 1
  fi
  devil www options "$domain" sslonly on >/dev/null 2>&1 || true
  webip="$(devil vhost list 2>/dev/null | awk '/web|Public|^[0-9]/{if($1 ~ /^[0-9.]+$/){print $1; exit}}')"
  [ -z "$webip" ] && webip="$(devil vhost list public 2>/dev/null | awk '$1 ~ /^[0-9.]+$/ {print $1; exit}')"
  if [ -n "$webip" ]; then
    devil ssl www add "$webip" le le "$domain" >/dev/null 2>&1 || true
  fi
  cat > "$APP_ROOT/config.json" <<EOF
{"domain":"$domain","port":"$port","webip":"$webip"}
EOF
  green "访问地址: https://$domain"
}
download_frontend(){
  mkdir -p "$SRC_DIR/public"
  rm -rf "$SRC_DIR/public/dist"
  tmp="$(mktemp -d)"
  curl -L "$WEB_DIST_URL" -o "$tmp/dist.tar.gz"
  tar -xzf "$tmp/dist.tar.gz" -C "$tmp"
  if [ -d "$tmp/dist" ]; then cp -R "$tmp/dist" "$SRC_DIR/public/dist"; else red "前端 dist 解压失败"; exit 1; fi
}
patch_source(){
  if [ -f "$INSTALLER_DIR/scripts/patch_abcd.py" ]; then
    python3 "$INSTALLER_DIR/scripts/patch_abcd.py"
  else
    curl -fsSL "$RAW_BASE/scripts/patch_abcd.py" -o /tmp/patch_abcd.py
    python3 /tmp/patch_abcd.py
  fi
}
build_abcd(){
  need git; need curl; need tar; need go; need python3
  mkdir -p "$APP_ROOT"
  if [ ! -d "$SRC_DIR/.git" ]; then
    rm -rf "$SRC_DIR"
    git clone --depth=1 "$SOURCE_REPO" "$SRC_DIR"
  else
    cd "$SRC_DIR" && git fetch --depth=1 origin && git reset --hard origin/HEAD
  fi
  cd "$SRC_DIR"
  download_frontend
  patch_source
  go build -o "$BIN" -tags=jsoniter .
  chmod +x "$BIN"
}
set_port_config(){
  port="$1"
  mkdir -p "$DATA_DIR"
  timeout 8 "$BIN" server --data "$DATA_DIR" >/dev/null 2>&1 || true
  python3 - "$DATA_DIR/config.json" "$port" <<'PY'
import json, sys
p=sys.argv[1]; port=int(sys.argv[2])
with open(p) as f: data=json.load(f)
data['scheme']={'address':'0.0.0.0','http_port':port,'https_port':-1,'force_https':False,'cert_file':'','key_file':'','unix_file':''}
with open(p,'w') as f: json.dump(data,f,indent=2)
PY
}
start_abcd(){
  [ -x "$BIN" ] || { red "未安装 abcd"; exit 1; }
  mkdir -p "$DATA_DIR"
  if pgrep -f "$BIN server --data $DATA_DIR" >/dev/null 2>&1; then green "abcd 已在运行"; return; fi
  nohup "$BIN" server --data "$DATA_DIR" >/dev/null 2>&1 &
  sleep 3
  pgrep -f "$BIN server --data $DATA_DIR" >/dev/null 2>&1 && green "abcd 启动成功" || { red "abcd 启动失败"; exit 1; }
}
stop_abcd(){ pkill -f "$BIN server --data $DATA_DIR" >/dev/null 2>&1 || true; }
reset_password(){
  pass="${1:-$DEFAULT_ADMIN_PASSWORD}"
  "$BIN" admin set "$pass" --data "$DATA_DIR" >/dev/null
  green "管理员账号: admin"
  green "管理员密码: $pass"
}
install_keepalive(){
  mkdir -p "$HOME/bin"
  if [ -f "$INSTALLER_DIR/keepalive.sh" ]; then cp "$INSTALLER_DIR/keepalive.sh" "$HOME/bin/abcd_keepalive.sh"; else curl -fsSL "$RAW_BASE/keepalive.sh" -o "$HOME/bin/abcd_keepalive.sh"; fi
  chmod +x "$HOME/bin/abcd_keepalive.sh"
  { crontab -l 2>/dev/null | grep -v 'abcd_keepalive.sh' | grep -v 'abcd_start.sh' || true; echo '@reboot /bin/sh $HOME/bin/abcd_keepalive.sh'; echo '*/5 * * * * /bin/sh $HOME/bin/abcd_keepalive.sh'; } | crontab -
  green "已配置开机自启和每 5 分钟保活"
}
install_all(){
  ensure_binexec
  port="$(reserve_port)"
  build_abcd
  set_port_config "$port"
  reset_password "$DEFAULT_ADMIN_PASSWORD"
  make_proxy_domain "$port"
  start_abcd
  install_keepalive
  green "安装完成"
}
install_self(){
  mkdir -p "$INSTALLER_DIR/scripts"
  if [ -f "$0" ]; then cp "$0" "$INSTALLER_DIR/start.sh"; else curl -fsSL "$RAW_BASE/start.sh" -o "$INSTALLER_DIR/start.sh"; fi
  curl -fsSL "$RAW_BASE/keepalive.sh" -o "$INSTALLER_DIR/keepalive.sh" || true
  curl -fsSL "$RAW_BASE/scripts/patch_abcd.py" -o "$INSTALLER_DIR/scripts/patch_abcd.py" || true
  chmod +x "$INSTALLER_DIR/start.sh" "$INSTALLER_DIR/keepalive.sh" 2>/dev/null || true
  touch "$HOME/.profile"
  grep -q 'alias ss=' "$HOME/.profile" || echo "alias ss='sh $INSTALLER_DIR/start.sh'" >> "$HOME/.profile"
  green "安装器已安装。重新登录后输入 ss 打开菜单。"
}
menu(){
  while true; do
    yellow "----------------------"
    echo "abcd for serv00"
    echo "1. 安装/重装 abcd"
    echo "2. 启动 abcd"
    echo "3. 停止 abcd"
    echo "4. 重置 admin 密码"
    echo "5. 重新编译更新 abcd"
    echo "6. 配置开机自启 + 5分钟保活"
    echo "0. 退出"
    printf "请选择: "; read n || exit 0
    case "$n" in
      1) install_all ;;
      2) start_abcd ;;
      3) stop_abcd ;;
      4) printf "新密码 [Abcd123!]: "; read p || true; reset_password "${p:-Abcd123!}" ;;
      5) build_abcd; stop_abcd; start_abcd ;;
      6) install_keepalive ;;
      0) exit 0 ;;
      *) red "无效选项" ;;
    esac
  done
}
case "${1:-}" in
  --install) install_self ;;
  --install-abcd) install_all ;;
  --start) start_abcd ;;
  --stop) stop_abcd ;;
  --keepalive) install_keepalive ;;
  *) menu ;;
esac
