import pathlib
import re
import shutil
import subprocess
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "app")

# ---------- AndroidManifest.xml ----------
manifest = root / "android/app/src/main/AndroidManifest.xml"
s = manifest.read_text(encoding="utf-8")

if "xmlns:tools" not in s:
    s = s.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    xmlns:tools="http://schemas.android.com/tools"',
        1,
    )

permissions = """    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
"""

audio_service = """        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
"""

s = s.replace("<application", permissions + "    <application", 1)
s = s.replace("</application>", audio_service + "    </application>", 1)
s = s.replace('android:label="musica_local"', 'android:label="Mi música"')
manifest.write_text(s, encoding="utf-8")


# ---------- Alias de actividad: permiten cambiar el icono de la app ----------
manifest_text = manifest.read_text(encoding="utf-8")
launcher_filter = re.compile(
    r"\s*<intent-filter>\s*<action android:name=\"android.intent.action.MAIN\"\s*/>\s*"
    r"<category android:name=\"android.intent.category.LAUNCHER\"\s*/>\s*</intent-filter>"
)
if launcher_filter.search(manifest_text) and "IconNormal" not in manifest_text:
    manifest_text = launcher_filter.sub("", manifest_text, count=1)

    def alias(name, icon, enabled):
        return (
            '        <activity-alias android:name=".%s"\n'
            '            android:targetActivity=".MainActivity"\n'
            '            android:exported="true"\n'
            '            android:enabled="%s"\n'
            '            android:icon="@mipmap/%s"\n'
            '            android:label="Mi música">\n'
            '            <intent-filter>\n'
            '                <action android:name="android.intent.action.MAIN"/>\n'
            '                <category android:name="android.intent.category.LAUNCHER"/>\n'
            '            </intent-filter>\n'
            '        </activity-alias>\n'
        ) % (name, enabled, icon)

    aliases = (
        alias("IconNormal", "ic_launcher", "true")
        + alias("IconDark", "ic_launcher_dark", "false")
        + alias("IconGlass", "ic_launcher_glass", "false")
    )
    manifest_text = manifest_text.replace("</application>", aliases + "    </application>", 1)
    manifest.write_text(manifest_text, encoding="utf-8")
    print("Alias de icono añadidos al manifest.")
else:
    print("AVISO: no se pudo preparar el cambio de icono (manifest distinto al esperado).")

# ---------- MainActivity.kt ----------
activity_dir = root / "android/app/src/main/kotlin/com/example/musica_local"
activity_dir.mkdir(parents=True, exist_ok=True)
(activity_dir / "MainActivity.kt").write_text(
    """package com.example.musica_local

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private var pendingPick: MethodChannel.Result? = null
    private val pickCode = 4711

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "musica_local/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotifications" -> {
                        // Android 13+: pedir permiso para mostrar la notificacion.
                        if (Build.VERSION.SDK_INT >= 33) {
                            val permission = "android.permission.POST_NOTIFICATIONS"
                            if (checkSelfPermission(permission) !=
                                PackageManager.PERMISSION_GRANTED
                            ) {
                                requestPermissions(arrayOf(permission), 1001)
                            }
                        }
                        result.success(null)
                    }
                    "pickImage" -> {
                        if (pendingPick != null) {
                            result.error("busy", "Ya hay una seleccion en curso", null)
                        } else {
                            pendingPick = result
                            val intent = Intent(Intent.ACTION_GET_CONTENT)
                            intent.type = "image/*"
                            intent.addCategory(Intent.CATEGORY_OPENABLE)
                            startActivityForResult(intent, pickCode)
                        }
                    }
                    "setLauncherIcon" -> {
                        val target = call.argument<String>("name") ?: "IconNormal"
                        val aliases = listOf("IconNormal", "IconDark", "IconGlass")
                        try {
                            // Primero se activa el elegido y luego se desactivan los demas.
                            for (alias in aliases) {
                                if (alias == target) {
                                    packageManager.setComponentEnabledSetting(
                                        ComponentName(this, "com.example.musica_local." + alias),
                                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                        PackageManager.DONT_KILL_APP
                                    )
                                }
                            }
                            for (alias in aliases) {
                                if (alias != target) {
                                    packageManager.setComponentEnabledSetting(
                                        ComponentName(this, "com.example.musica_local." + alias),
                                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                        PackageManager.DONT_KILL_APP
                                    )
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickCode) return
        val pending = pendingPick
        pendingPick = null
        if (pending == null) return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(null)
            return
        }
        try {
            val out = File(cacheDir, "picked_" + System.currentTimeMillis() + ".img")
            contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { output -> input.copyTo(output) }
            }
            pending.success(out.absolutePath)
        } catch (e: Exception) {
            pending.success(null)
        }
    }
}
""",
    encoding="utf-8",
)

# ---------- Icono de la app (adaptativo, rojo con nota blanca) ----------
res = root / "android/app/src/main/res"
(res / "drawable").mkdir(parents=True, exist_ok=True)
(res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)

(res / "drawable/ic_launcher_background.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:angle="270"
        android:startColor="#FF5E72"
        android:endColor="#FA233B"
        android:type="linear"/>
</shape>
""",
    encoding="utf-8",
)

(res / "drawable/ic_launcher_foreground.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:scaleX="1.15"
        android:scaleY="1.15"
        android:pivotX="53"
        android:pivotY="54.5">
        <path android:fillColor="#FFFFFFFF" android:pathData="M44,38 L72,31 L72,40 L44,47 Z"/>
        <path android:fillColor="#FFFFFFFF" android:pathData="M44,38 L48,38 L48,71 L44,71 Z"/>
        <path android:fillColor="#FFFFFFFF" android:pathData="M68,31 L72,31 L72,66 L68,66 Z"/>
        <path android:fillColor="#FFFFFFFF" android:pathData="M34,71 a7,7 0 1,0 14,0 a7,7 0 1,0 -14,0 Z"/>
        <path android:fillColor="#FFFFFFFF" android:pathData="M58,66 a7,7 0 1,0 14,0 a7,7 0 1,0 -14,0 Z"/>
    </group>
</vector>
""",
    encoding="utf-8",
)

(res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
""",
    encoding="utf-8",
)


# ---------- Iconos alternativos: oscuro (plateado) y cristal (transparente) ----------
(res / "drawable/ic_launcher_dark_background.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:angle="270"
        android:startColor="#424246"
        android:endColor="#08080A"
        android:type="linear"/>
</shape>
""",
    encoding="utf-8",
)

(res / "drawable/ic_launcher_dark_foreground.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:scaleX="1.15"
        android:scaleY="1.15"
        android:pivotX="53"
        android:pivotY="54.5">
        <path android:fillColor="#FFE9E9EE" android:pathData="M44,38 L72,31 L72,40 L44,47 Z"/>
        <path android:fillColor="#FFE0E0E6" android:pathData="M44,38 L48,38 L48,71 L44,71 Z"/>
        <path android:fillColor="#FFE0E0E6" android:pathData="M68,31 L72,31 L72,66 L68,66 Z"/>
        <path android:fillColor="#FFC4C5CE" android:pathData="M34,71 a7,7 0 1,0 14,0 a7,7 0 1,0 -14,0 Z"/>
        <path android:fillColor="#FFC4C5CE" android:pathData="M58,66 a7,7 0 1,0 14,0 a7,7 0 1,0 -14,0 Z"/>
    </group>
</vector>
""",
    encoding="utf-8",
)

(res / "mipmap-anydpi-v26/ic_launcher_dark.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_dark_background"/>
    <foreground android:drawable="@drawable/ic_launcher_dark_foreground"/>
</adaptive-icon>
""",
    encoding="utf-8",
)

(res / "drawable/ic_launcher_glass_background.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:angle="270"
        android:startColor="#5CFFFFFF"
        android:endColor="#1FFFFFFF"
        android:type="linear"/>
</shape>
""",
    encoding="utf-8",
)

(res / "drawable/ic_launcher_glass_foreground.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:scaleX="1.15"
        android:scaleY="1.15"
        android:pivotX="53"
        android:pivotY="54.5">
        <group android:translateY="1.6">
            <path android:fillColor="#40003050" android:pathData="M44,38 L72,31 L72,40 L44,47 Z"/>
            <path android:fillColor="#40003050" android:pathData="M44,38 L48,38 L48,71 L44,71 Z"/>
            <path android:fillColor="#40003050" android:pathData="M68,31 L72,31 L72,66 L68,66 Z"/>
            <path android:fillColor="#40003050" android:pathData="M34,71 a7,7 0 1,0 14,0 a7,7 0 1,0 -14,0 Z"/>
            <path android:fillColor="#40003050" android:pathData="M58,66 a7,7 0 1,0 14,0 a7,7 0 1,0 -14,0 Z"/>
        </group>
        <path android:fillColor="#F2FFFFFF" android:pathData="M44,38 L72,31 L72,40 L44,47 Z"/>
        <path android:fillColor="#F2FFFFFF" android:pathData="M44,38 L48,38 L48,71 L44,71 Z"/>
        <path android:fillColor="#F2FFFFFF" android:pathData="M68,31 L72,31 L72,66 L68,66 Z"/>
        <path android:fillColor="#F2FFFFFF" android:pathData="M34,71 a7,7 0 1,0 14,0 a7,7 0 1,0 -14,0 Z"/>
        <path android:fillColor="#F2FFFFFF" android:pathData="M58,66 a7,7 0 1,0 14,0 a7,7 0 1,0 -14,0 Z"/>
    </group>
</vector>
""",
    encoding="utf-8",
)

(res / "mipmap-anydpi-v26/ic_launcher_glass.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_glass_background"/>
    <foreground android:drawable="@drawable/ic_launcher_glass_foreground"/>
</adaptive-icon>
""",
    encoding="utf-8",
)

# PNG de respaldo (Android < 8 y recurso por defecto para evitar avisos de lint)
icons_src = pathlib.Path(__file__).resolve().parent / "icons" / "res"
if icons_src.exists():
    for density_dir in sorted(icons_src.iterdir()):
        if density_dir.is_dir():
            target = res / density_dir.name
            target.mkdir(parents=True, exist_ok=True)
            for png in density_dir.glob("*.png"):
                shutil.copy(png, target / png.name)

# ---------- Icono pequeño de la notificación (blanco, monocromo) ----------
(res / "drawable/ic_music_note.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,3v10.55c-0.59,-0.34 -1.27,-0.55 -2,-0.55 -2.21,0 -4,1.79 -4,4s1.79,4 4,4 4,-1.79 4,-4V7h4V3h-6z"/>
</vector>
""",
    encoding="utf-8",
)


# ---------- Que el recortador de recursos NO borre los iconos ----------
# El icono de la notificación se busca por nombre desde el código nativo, así
# que el recortador de la versión release lo consideraba "sin uso" y lo
# eliminaba. Eso hacía que la app se cerrara al empezar a reproducir.
(res / "raw").mkdir(parents=True, exist_ok=True)
(res / "raw/keep.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_music_note,@drawable/ic_launcher_*,@mipmap/ic_launcher*" />
""",
    encoding="utf-8",
)

# ---------- Release sin recorte de código ni de recursos ----------
for gradle_name, kotlin_dsl in (("build.gradle.kts", True), ("build.gradle", False)):
    gradle = root / "android/app" / gradle_name
    if not gradle.exists():
        continue
    text = gradle.read_text(encoding="utf-8")
    if "shrinkResources" in text or "ShrinkResources" in text:
        break
    flags = (
        "            isMinifyEnabled = false\n            isShrinkResources = false\n"
        if kotlin_dsl
        else "            minifyEnabled false\n            shrinkResources false\n"
    )
    patched = re.sub(r"(release\s*\{\n)", lambda m: m.group(1) + flags, text, count=1)
    if patched != text:
        gradle.write_text(patched, encoding="utf-8")
        print(f"Recorte desactivado en {gradle_name}")
    else:
        print(f"AVISO: no encontré el bloque release en {gradle_name}")
    break

# ---------- Paquetes extra ----------
# Se instalan aquí (y no solo en el workflow) para que funcione aunque el
# archivo del workflow en GitHub sea una versión antigua.
if shutil.which("flutter"):
    # permission_handler ya no se usa (pide una versión de Android demasiado
    # nueva); el permiso de notificaciones se pide desde MainActivity.
    subprocess.run(["flutter", "pub", "remove", "permission_handler"], cwd=root, check=False)
    subprocess.run(["flutter", "pub", "add", "path_provider"], cwd=root, check=True)
else:
    print("flutter no está en el PATH; se omite la instalación de paquetes extra.")

print("Proyecto Android configurado.")
