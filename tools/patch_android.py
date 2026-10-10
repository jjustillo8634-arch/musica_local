import pathlib
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

# ---------- MainActivity.kt ----------
activity_dir = root / "android/app/src/main/kotlin/com/example/musica_local"
activity_dir.mkdir(parents=True, exist_ok=True)
(activity_dir / "MainActivity.kt").write_text(
    "package com.example.musica_local\n\n"
    "import com.ryanheise.audioservice.AudioServiceActivity\n\n"
    "class MainActivity : AudioServiceActivity()\n",
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

# ---------- Paquetes extra ----------
# Se instalan aquí (y no solo en el workflow) para que funcione aunque el
# archivo del workflow en GitHub sea una versión antigua.
EXTRA_PACKAGES = ["path_provider", "permission_handler"]
if shutil.which("flutter"):
    subprocess.run(["flutter", "pub", "add", *EXTRA_PACKAGES], cwd=root, check=True)
else:
    print("flutter no está en el PATH; se omite la instalación de paquetes extra.")

print("Proyecto Android configurado.")
