#!/usr/bin/env bash
# Compila el APK para el cliente, pero solo si todo está en orden.
#
# Existe porque el 12/08/2026 se compilaron siete APK en una tarde y en varias
# de ellas faltaba algo: una vez el código no compilaba, otra la versión no
# había subido en los tres archivos. Cada fallo costaba una vuelta entera de
# «instálalo y dime qué sale».
#
# Uso, desde moto_taller_app/:
#     bash herramientas/entregar.sh
#
# No firma nada por su cuenta ni sube nada a ninguna parte: compila con el
# keystore que ya tiene configurado el proyecto y comprueba que la huella
# coincida con la de producción. Si no coincide, Android rechazaría la
# actualización y la única salida sería desinstalar — que borra la base de
# datos del teléfono.

set -euo pipefail

# Huella del certificado con el que están firmadas las versiones que el cliente
# ya tiene instaladas. Si cambia, el teléfono no aceptará la actualización.
HUELLA_PRODUCCION="58174d3e0336f36d3878b28945566bd0c15c52f89520a89ff6d121edc48a9699"

rojo()     { printf '\033[31m%s\033[0m\n' "$1"; }
amarillo() { printf '\033[33m%s\033[0m\n' "$1"; }
verde()    { printf '\033[32m%s\033[0m\n' "$1"; }
paso()  { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

fallar() { rojo "✗ $1"; exit 1; }

# ── 1. El código compila y las pruebas pasan ────────────────────────────────
paso "Análisis estático"
flutter analyze --no-fatal-infos || fallar "Hay errores o warnings. No se entrega."
verde "✓ sin errores ni warnings"

paso "Pruebas"
flutter test || fallar "Hay pruebas en rojo. No se entrega."
verde "✓ todas en verde"

# ── 2. La versión sube en los tres archivos a la vez ────────────────────────
paso "Coherencia de versiones"
CODE=$(grep -oP 'versionCode = \K\d+' android/app/build.gradle.kts)
NAME=$(grep -oP 'versionName = "\K[^"]+' android/app/build.gradle.kts)
PUBSPEC=$(grep -oP '^version: \K.+' pubspec.yaml)
CONFIG=$(grep -oP "appVersion = '\K[^']+" lib/core/config/app_config.dart)

echo "  build.gradle.kts : $NAME+$CODE"
echo "  pubspec.yaml     : $PUBSPEC"
echo "  app_config.dart  : $CONFIG"

[ "$PUBSPEC" = "$NAME+$CODE" ] || fallar "pubspec.yaml no coincide con build.gradle.kts"
[ "$CONFIG"  = "$NAME" ]       || fallar "AppConfig.appVersion no coincide con versionName"
verde "✓ los tres coinciden"

# ── 3. El versionCode es mayor que el del último APK entregado ──────────────
# Android rechaza en silencio una actualización con versionCode igual o menor.
paso "El versionCode avanza"
ULTIMO=$(ls -1 ../mecanix-v*.apk 2>/dev/null | sed 's/.*mecanix-v//;s/\.apk//' | sort -V | tail -1 || true)
if [ -n "$ULTIMO" ]; then
  echo "  último APK en Desktop/Jp: v$ULTIMO"
  if [ "$ULTIMO" = "$NAME" ]; then
    fallar "Ya existe mecanix-v$NAME.apk. Sube la versión antes de entregar."
  fi
fi
verde "✓ versión nueva: $NAME (código $CODE)"

# ── 4. Compilar ─────────────────────────────────────────────────────────────
# La clave de Gemini se inyecta al compilar; nunca vive en el código. Si no
# está, la app compila igual y la función de identificar repuestos por foto se
# desactiva sola con un mensaje claro.
DEFINES=()
if [ -n "${GEMINI_API_KEY:-}" ]; then
  DEFINES+=("--dart-define=GEMINI_API_KEY=$GEMINI_API_KEY")
  echo "  clave de Gemini: inyectada"
else
  amarillo "  GEMINI_API_KEY no esta definida: identificar por foto quedara desactivada."
  echo "    Para incluirla:  GEMINI_API_KEY=... bash herramientas/entregar.sh"
fi

paso "Compilando APK de release"
flutter build apk --release "${DEFINES[@]}" || fallar "La compilación falló."

APK="build/app/outputs/flutter-apk/app-release.apk"
DESTINO="../mecanix-v$NAME.apk"
cp "$APK" "$DESTINO"
verde "✓ $DESTINO"

# ── 5. La firma coincide con la de producción ───────────────────────────────
paso "Verificando la firma"
APKSIGNER=$(ls "$LOCALAPPDATA/Android/Sdk/build-tools/"*/apksigner.bat 2>/dev/null | sort -V | tail -1 || true)
[ -n "$APKSIGNER" ] || fallar "No se encontró apksigner. Verifica la firma a mano antes de entregar."

HUELLA=$("$APKSIGNER" verify --print-certs "$DESTINO" 2>/dev/null \
  | grep -i "SHA-256 digest" | head -1 | awk '{print $NF}')

echo "  esperada: $HUELLA_PRODUCCION"
echo "  obtenida: $HUELLA"

if [ "$HUELLA" != "$HUELLA_PRODUCCION" ]; then
  rm -f "$DESTINO"
  fallar "LA FIRMA NO COINCIDE. El APK se ha borrado.
   Si se entregara, Android rechazaría la actualización y la única salida sería
   desinstalar — lo que borra la base de datos del teléfono del cliente."
fi
verde "✓ firma correcta"

printf '\n'
verde "═══════════════════════════════════════════════"
verde " Listo para entregar: mecanix-v$NAME.apk"
verde "═══════════════════════════════════════════════"
printf '\n'
echo "Recuérdale al cliente: se ACTUALIZA encima. Nunca desinstalar."
echo "Antes de cualquier desinstalación, la pantalla de sincronización tiene"
echo "que decir «No queda nada por subir»."
