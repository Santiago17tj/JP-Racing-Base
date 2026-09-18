# Política de privacidad — Mecanix

**Última actualización: 17 de septiembre de 2026.**

⚠️ **Este es un borrador técnico, no un documento legal.** Lo redacté yo
(el asistente que desarrolla la app) para describir con precisión qué datos
recoge Mecanix y qué se hace con ellos, porque hoy el proyecto no tenía
ningún documento de este tipo. **Antes de publicarlo o de usarlo como enlace
en la pantalla de consentimiento de Google, alguien con criterio legal en
Colombia (Ley 1581 de 2012, habeas data) debería revisarlo.** Yo no soy
abogado y no puedo certificar que esto cumpla la ley — solo que describe con
exactitud lo que el código hace hoy, 17/09/2026.

---

## Quién ofrece Mecanix

Mecanix es una aplicación para la gestión de talleres de motocicletas
(clientes, vehículos, órdenes de trabajo, inventario y facturación). La usa
el dueño o el personal de un taller — no el cliente final del taller.

## Qué datos se recogen

**Del dueño del taller (quien usa la app):**
- Correo electrónico, a través del inicio de sesión con Google.
- Nombre, teléfono, dirección y logo del taller, si los introduce en Ajustes.

**De los clientes del taller, introducidos por quien usa la app:**
- Nombre completo, tipo y número de documento de identidad.
- Teléfono, correo electrónico y dirección (cuando se registran).
- Datos del vehículo: placa, marca, modelo, año, kilometraje.
- Historial de órdenes de trabajo, diagnósticos, repuestos usados y montos
  cobrados.

Mecanix no recoge estos datos directamente de los clientes del taller: los
introduce el propio taller, que es responsable de haber obtenido el
consentimiento correspondiente antes de registrarlos.

## Para qué se usan

Exclusivamente para que el taller gestione su propio negocio: crear órdenes
de trabajo, imprimir facturas, llevar el inventario y la caja, y —si el
dueño lo activa— enviar un recordatorio de mantenimiento por WhatsApp al
cliente.

Estos datos **no se usan con fines publicitarios** y **no se venden ni se
comparten con terceros**, salvo los proveedores técnicos necesarios para que
la app funcione (ver abajo).

## Dónde se guardan

- **Supabase** (supabase.com), como base de datos en la nube. Cada taller
  solo puede ver sus propios datos: la base impone esa separación con
  políticas de seguridad a nivel de fila (Row Level Security), no es solo
  un filtro en la pantalla.
- **En el teléfono**, en una base de datos local (SQLite), para poder seguir
  trabajando sin conexión a internet. Esa copia local no sale del
  dispositivo salvo que el dueño del taller use la función de respaldo
  (ver abajo) para compartirla él mismo.
- **Google**, únicamente para el inicio de sesión (Google Sign-In /
  Supabase Auth). Mecanix nunca ve ni guarda la contraseña de esa cuenta.
- Si el dueño del taller sube un logo, ese archivo queda en un espacio de
  almacenamiento de Supabase cuya URL es pública (cualquiera que la
  conozca puede verla) — pensado para un logo comercial, no para
  documentos sensibles.

## Copia de seguridad, a iniciativa del propio taller

Desde Ajustes, el dueño del taller puede generar un archivo (JSON o CSV) con
todos sus datos y compartirlo como quiera —por WhatsApp, correo, guardarlo en
su teléfono—. Esa exportación la controla enteramente el taller: la app no
la envía a ningún sitio por su cuenta.

## Permisos del teléfono que pide la app

- **Cámara**: para escanear códigos de barras de repuestos y, si está
  configurado, para identificar repuestos por foto con IA.
- **Internet**: para sincronizar con la nube.

No pide acceso a contactos, ubicación, archivos ni micrófono.

## Cuánto tiempo se conservan los datos

Mientras la cuenta del taller exista en Supabase. Si el dueño del taller
quiere eliminar su cuenta y sus datos, debe solicitarlo directamente
(hoy no hay un botón de autoeliminación dentro de la app).

## Contacto

Este documento no incluye todavía un correo ni canal de contacto formal del
responsable del tratamiento de datos — hay que añadirlo antes de publicarlo.
