# my-tv

Settings for one TV: a Vestel Cosmos170 (sold as Toshiba/JVC/Hitachi/Telefunken in Europe), Android TV 11.

- `launcher/app/src/main/res/values/config.xml`: dock of six streaming apps in one row, 6 columns, frosted dock,
  no greeting, 32-bit wallpapers, advanced effects, and `wallpaper_fade_ms` 1200 (the crossfade added in this fork).
- `themes/dark-fantasy`: 16 Romantic-era paintings and moody castle photos, rotating every minute.
- `push.sh`: installs the built launcher with plain `adb` and pushes the theme. It refuses to replace or restart the
  launcher while one of its accessibility services is enabled: on this firmware that crashes system_server.

Build: `cd launcher && ./gradlew assembleRelease`, then `TV_HOST=<tv ip> my-tv/push.sh`.
