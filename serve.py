#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import http.server
import socketserver
import os
import sys
import mimetypes

PORT = 8080

# Force UTF-8 encoding for stdout
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# Register correct MIME types globally
mimetypes.init()
mimetypes.add_type('application/wasm', '.wasm')
mimetypes.add_type('application/javascript', '.js')

class FlutterHandler(http.server.SimpleHTTPRequestHandler):
    def guess_type(self, path):
        # Explicit override to ensure correct mime type is returned
        if path.endswith('.wasm'):
            return 'application/wasm'
        if path.endswith('.js'):
            return 'application/javascript'
        return super().guess_type(path)

    def end_headers(self):
        # NOTE: COOP y COEP removidos para evitar que bloqueen los redireccionamientos y accesos locales de Google OAuth.
        # Solo aplicar no-cache en HTML para asegurar carga de la última versión.
        if self.path.endswith('.html') or self.path == '/':
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        else:
            self.send_header('Cache-Control', 'max-age=3600')
        super().end_headers()

    def log_message(self, format, *args):
        try:
            print(f"[{self.address_string()}] {format % args}")
        except Exception:
            pass

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web'))

print(f"MotoTaller Server -> http://localhost:{PORT}")
print(f"Directorio: {os.getcwd()}")
print("WASM MIME type: OK | COOP/COEP headers: REMOVIDOS para OAuth | Clear-Site-Data: ELIMINADO")
print("Presiona Ctrl+C para detener")

with socketserver.ThreadingTCPServer(("", PORT), FlutterHandler) as httpd:
    httpd.serve_forever()

