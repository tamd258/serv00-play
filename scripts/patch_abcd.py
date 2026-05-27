#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path.cwd()
DIST = ROOT / "public" / "dist"


def read(path):
    return (ROOT / path).read_text(errors="ignore")


def write(path, text):
    (ROOT / path).write_text(text)


def replace(path, old, new, required=False):
    p = ROOT / path
    s = p.read_text(errors="ignore")
    if old not in s:
        if required:
            raise SystemExit(f"missing pattern in {path}: {old[:80]!r}")
        return False
    p.write_text(s.replace(old, new))
    return True


def patch_auth():
    p = ROOT / "server/handles/auth.go"
    s = p.read_text(errors="ignore")

    s = s.replace('Issuer:      "Alist",', 'Issuer:      "abcd",')
    s = s.replace('登录Alist失败:', '登录abcd失败:')

    old_login = '''func Login(c *gin.Context) {
	var req LoginReq
	if err := c.ShouldBind(&req); err != nil {
		common.ErrorResp(c, err, 400)
		return
	}
	req.Password = model.StaticHash(req.Password)
	loginHash(c, &req)
}'''
    new_login = '''func Login(c *gin.Context) {
	var req LoginReq
	if err := c.ShouldBind(&req); err != nil {
		common.ErrorResp(c, err, 400)
		return
	}
	if !isSHA256Hex(req.Password) {
		req.Password = model.StaticHash(req.Password)
	}
	loginHash(c, &req)
}

func isSHA256Hex(s string) bool {
	if len(s) != 64 {
		return false
	}
	for _, r := range s {
		if (r < '0' || r > '9') && (r < 'a' || r > 'f') && (r < 'A' || r > 'F') {
			return false
		}
	}
	return true
}'''
    if old_login in s:
        s = s.replace(old_login, new_login)

    old_hash = '''func LoginHash(c *gin.Context) {
	var req LoginReq
	if err := c.ShouldBind(&req); err != nil {
		common.ErrorResp(c, err, 400)
		return
	}
	loginHash(c, &req)
}'''
    new_hash = '''func LoginHash(c *gin.Context) {
	var req LoginReq
	if err := c.ShouldBind(&req); err != nil {
		common.ErrorResp(c, err, 400)
		return
	}
	if !isSHA256Hex(req.Password) {
		req.Password = model.StaticHash(req.Password)
	}
	loginHash(c, &req)
}'''
    if old_hash in s:
        s = s.replace(old_hash, new_hash)

    p.write_text(s)


def patch_router():
    p = ROOT / "server/router.go"
    s = p.read_text(errors="ignore")
    if 'auth.GET("/me", handles.CurrentUser)' in s and 'auth.POST("/me", handles.CurrentUser)' not in s:
        s = s.replace('auth.GET("/me", handles.CurrentUser)', 'auth.GET("/me", handles.CurrentUser)\n\tauth.POST("/me", handles.CurrentUser)')
    if 'public.Any("/settings", handles.PublicSettings)' in s and 'public.Any("/archive_extensions", handles.PublicArchiveExtensions)' not in s:
        s = s.replace('public.Any("/settings", handles.PublicSettings)', 'public.Any("/settings", handles.PublicSettings)\n\tpublic.Any("/archive_extensions", handles.PublicArchiveExtensions)')
    p.write_text(s)


def patch_settings():
    p = ROOT / "server/handles/setting.go"
    s = p.read_text(errors="ignore")
    old = '''func PublicSettings(c *gin.Context) {
	common.SuccessResp(c, op.GetPublicSettingsMap())
}'''
    new = '''func PublicSettings(c *gin.Context) {
	settings := op.GetPublicSettingsMap()
	if _, ok := settings["use_newui"]; !ok {
		settings["use_newui"] = "false"
	}
	if _, ok := settings["allow_register"]; !ok {
		settings["allow_register"] = "false"
	}
	common.SuccessResp(c, settings)
}

func PublicArchiveExtensions(c *gin.Context) {
	common.SuccessResp(c, []string{})
}'''
    if old in s:
        s = s.replace(old, new)
    elif 'func PublicArchiveExtensions' not in s:
        s += '\n' + new + '\n'
    p.write_text(s)


def patch_defaults():
    p = ROOT / "internal/bootstrap/data/setting.go"
    s = p.read_text(errors="ignore")
    s = s.replace('{Key: conf.SiteTitle, Value: "AList"', '{Key: conf.SiteTitle, Value: "abcd"')
    s = s.replace('https://cdn.jsdelivr.net/gh/alist-org/logo@main/logo.svg', '/images/abcd-logo.svg')
    p.write_text(s)


def patch_user():
    p = ROOT / "internal/model/user.go"
    if p.exists():
        s = p.read_text(errors="ignore")
        s = s.replace('return "https://alist.nn.ci/logo.svg"', 'return "/images/abcd-logo.svg"')
        p.write_text(s)


def patch_static():
    p = ROOT / "server/static/static.go"
    if not p.exists():
        return
    s = p.read_text(errors="ignore")
    # Add no-store headers for SPA HTML fallback. Keep asset routes untouched.
    if 'c.Header("Cache-Control", "no-store")' not in s:
        s = s.replace('c.Header("Content-Type", "text/html")', 'c.Header("Content-Type", "text/html")\n\t\tc.Header("Cache-Control", "no-store")')
    p.write_text(s)


def patch_frontend():
    if not DIST.exists():
        return
    (DIST / "images").mkdir(parents=True, exist_ok=True)
    (DIST / "images" / "abcd-logo.svg").write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><rect width="128" height="128" rx="28" fill="#171717"/><text x="64" y="77" font-family="Arial, sans-serif" font-size="42" text-anchor="middle" fill="#fff" font-weight="700">abcd</text></svg>''')

    adapter = r'''
    <script>
      (function () {
        function adapt(body) {
          if (body && body.code === 200 && body.data) {
            if (!Array.isArray(body.data.role)) body.data.role = [body.data.role];
            if (!Array.isArray(body.data.permissions)) body.data.permissions = [{ path: body.data.base_path || '/', permission: body.data.permission || 0 }];
          }
          return body;
        }
        var originalFetch = window.fetch;
        if (originalFetch) {
          window.fetch = function () {
            var args = arguments;
            return originalFetch.apply(this, args).then(function (response) {
              var url = '';
              try { var input = args[0]; url = typeof input === 'string' ? input : (input && input.url) || ''; } catch (e) {}
              if (url.indexOf('/api/me') === -1) return response;
              return response.clone().json().then(function (body) {
                body = adapt(body);
                return new Response(JSON.stringify(body), { status: response.status, statusText: response.statusText, headers: response.headers });
              }).catch(function () { return response; });
            });
          };
        }
        if (window.XMLHttpRequest) {
          var OriginalXHR = window.XMLHttpRequest;
          window.XMLHttpRequest = function () {
            var xhr = new OriginalXHR();
            var targetUrl = '';
            var open = xhr.open;
            var send = xhr.send;
            xhr.open = function (method, url) { targetUrl = url || ''; return open.apply(xhr, arguments); };
            xhr.send = function () {
              if (targetUrl.indexOf('/api/me') !== -1) {
                xhr.addEventListener('readystatechange', function () {
                  if (xhr.readyState !== 4) return;
                  try {
                    var body = adapt(JSON.parse(xhr.responseText));
                    Object.defineProperty(xhr, 'responseText', { value: JSON.stringify(body) });
                    Object.defineProperty(xhr, 'response', { value: JSON.stringify(body) });
                  } catch (e) {}
                });
              }
              return send.apply(xhr, arguments);
            };
            return xhr;
          };
        }
      })();
    </script>'''

    for path in DIST.rglob('*'):
        if not path.is_file():
            continue
        try:
            s = path.read_text(errors="ignore")
        except Exception:
            continue
        original = s
        s = s.replace('AList', 'abcd').replace('Alist', 'abcd').replace('alist', 'abcd')
        s = s.replace('https://cdn.jsdelivr.net/gh/abcd-org/logo@main/logo.svg', '/images/abcd-logo.svg')
        s = s.replace('https://jsd.nn.ci/gh/abcd-org/logo@main/logo.png', '/images/abcd-logo.svg')
        s = s.replace('https://cdn.jsdelivr.net/gh/alist-org/logo@main/logo.svg', '/images/abcd-logo.svg')
        s = s.replace('https://jsd.nn.ci/gh/alist-org/logo@main/logo.png', '/images/abcd-logo.svg')
        s = re.sub(r'\s*<script\s+src="https://g\.alicdn\.com/IMM/office-js/1\.1\.5/aliyun-web-office-sdk\.min\.js"\s+async\s*></script>', '', s)
        if path.name == 'index.html':
            s = s.replace('<title>rb</title>', '<title>abcd</title>')
            s = s.replace('<title>AList</title>', '<title>abcd</title>')
            if 'function adapt(body)' not in s:
                s = s.replace('<head>', '<head>\n' + adapter, 1)
        if s != original:
            path.write_text(s)


def main():
    patch_auth()
    patch_router()
    patch_settings()
    patch_defaults()
    patch_user()
    patch_static()
    patch_frontend()
    print('abcd patch applied')


if __name__ == '__main__':
    main()
