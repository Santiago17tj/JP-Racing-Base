# 🛠️ Guía de Instalación de Flutter en Windows

Para ejecutar el código fuente que acabamos de crear en tu computadora, sigue estos sencillos pasos para configurar tu entorno de desarrollo.

---

### Paso 1: Descargar el SDK de Flutter

1. Ve a la página oficial de descargas de Flutter:
   👉 **[https://docs.flutter.dev/get-started/install/windows/mobile](https://docs.flutter.dev/get-started/install/windows/mobile)**
2. Haz clic en el botón azul para descargar el archivo ZIP del SDK de Flutter (ej. `flutter_windows_3.22.x-stable.zip`).
3. Crea una carpeta en tu disco local `C:\` llamada `src`. (Quedará como `C:\src`).
4. Descomprime el contenido del archivo ZIP descargado dentro de esa carpeta. La ruta final debe ser:
   📁 `C:\src\flutter`

> [!WARNING]
> No instales Flutter en carpetas del sistema como `C:\Program Files` ya que requiere privilegios elevados de administrador y puede causar errores de compilación.

---

### Paso 2: Configurar las Variables de Envono (PATH)

Para que tu sistema reconozca el comando `flutter` en cualquier terminal:

1. Presiona la tecla **Windows** y escribe: `variables de entorno`.
2. Selecciona **Editar las variables de entorno del sistema**.
3. En la ventana que se abre, haz clic en el botón **Variables de entorno...** (abajo a la derecha).
4. En la sección superior ("Variables de usuario para..."), busca la variable llamada **Path** y haz doble clic sobre ella.
5. Haz clic en el botón **Nuevo** y escribe exactamente la siguiente ruta:
   `C:\src\flutter\bin`
6. Haz clic en **Aceptar** en todas las ventanas para guardar los cambios.

---

### Paso 3: Configurar VS Code

1. Abre **Visual Studio Code**.
2. Ve al panel de extensiones (el icono de 4 cuadrados en la barra lateral izquierda, o presiona `Ctrl + Shift + X`).
3. Busca la extensión **Flutter** (desarrollada por *Dart Code*) e instálala. Esto instalará automáticamente la extensión de **Dart**.

---

### Paso 4: Validar la Instalación

Cierra todas las terminales que tengas abiertas (para actualizar el PATH) y abre una nueva terminal en VS Code o PowerShell, luego ejecuta:

```powershell
flutter doctor
```

Este comando analizará tu computadora e indicará qué componentes faltan. Por ahora, nos centraremos en **Chrome** para poder probar y correr la aplicación rápidamente en el navegador web sin tener que descargar el pesado emulador de Android Studio hoy.

---

### Paso 5: Ejecutar la Aplicación

1. En VS Code, abre la carpeta del proyecto en:
   📁 `c:\Users\Isabel\Desktop\Jp\moto_taller_app`
2. Abre la terminal integrada de VS Code (`Ctrl + Ñ` o `Menú Superior -> Terminal -> Nueva terminal`).
3. Asegura que las dependencias estén listas ejecutando:
   ```powershell
   flutter pub get
   ```
4. Para ejecutar la app en tu navegador Chrome, corre:
   ```powershell
   flutter run -d chrome
   ```
   *(Esto abrirá Chrome de inmediato y cargará la interfaz de tu taller de motocicletas con el inventario inteligente y las órdenes de servicio que creamos).*
