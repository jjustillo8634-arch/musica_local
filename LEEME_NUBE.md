# Compilar el APK en la nube (sin instalar nada)

## 1. Subir el proyecto a GitHub (una sola vez)

1. Crea una cuenta en github.com (si no tienes) y pulsa **New repository**. Nómbralo `musica_local` y créalo.
2. Descomprime `musica_local.zip` en tu computadora.
3. En el repositorio, pulsa **Add file → Upload files** y arrastra **todo el contenido** de la carpeta (incluida `.github`, `lib` y `tools`).
   - Si `.github` no aparece en tu explorador de archivos, es una carpeta oculta (en Mac: `Cmd + Shift + .`).
   - Si GitHub no te deja subirla, usa **Add file → Create new file** y escribe como nombre `.github/workflows/build-apk.yml`; pega ahí el contenido del archivo.
4. Pulsa **Commit changes**.

## 2. Descargar el APK

1. Entra a la pestaña **Actions** del repositorio. Verás la ejecución "Compilar APK" (tarda unos 5 a 10 minutos).
2. Cuando salga la palomita verde, ábrela y baja hasta **Artifacts**. Descarga `musica-local-apk`.
3. Descomprime el .zip: dentro está `app-release.apk`.

## 3. Instalar en el teléfono

1. Pasa el APK al teléfono (cable USB, Google Drive o WhatsApp a ti mismo).
2. Ábrelo desde el teléfono. Si Android lo pide, permite **instalar apps de origen desconocido** para esa app (Archivos o Chrome).
3. Abre **Mi música** y concede el permiso de audio.

## Cada vez que cambiemos el código

Reemplaza el archivo modificado en GitHub (**abre el archivo → lápiz ✏️ → pega → Commit**). Se compila solo y repites el paso 2.

## Si falla la compilación

En **Actions**, abre la ejecución con la ❌, entra al paso que falló y copia el mensaje de error. Pégamelo y lo corrijo.
