import pathlib
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

print("Proyecto Android configurado.")
