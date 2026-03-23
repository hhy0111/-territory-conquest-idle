$env:JAVA_HOME="C:\\Program Files\\Android\\Android Studio\\jbr"
$env:ANDROID_SDK_ROOT="C:\\Users\\<USER>\\AppData\\Local\\Android\\Sdk"

$env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH="D:\\keys\\debug.keystore"
$env:GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH="D:\\keys\\territory-conquest-release.keystore"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER="territoryconquest"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="<CHANGE_ME>"

# For local QA only, you can generate a temporary release keystore with:
# .\tools\android\generate_local_release_keystore.ps1 -WriteEnvScript
# Then load:
# .\.local\android\use_local_release_keystore.ps1
