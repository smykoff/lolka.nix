[English](README.md) | Русский

# lolka.nix

Nix flake с пакетом [Lolka](https://lolka.app) — Electron-приложением для
голосового чата и демонстрации экрана.

Пакет перепаковывает официальный готовый `.deb` из
`https://storage.yandexcloud.net/lolka-electron/releases`. Публичных исходников
нет, поэтому сборка из исходников в песочнице Nix невозможна.

## Поддерживаемые платформы

| Система        | Статус    |
|----------------|-----------|
| `x86_64-linux` | проверено |

Upstream собирает пакеты только под Linux x86_64, поэтому другие системы не
объявлены.

## Использование

Запуск без установки:

```sh
nix run github:<REPO>
```

Установка в профиль пользователя:

```sh
nix profile install github:<REPO>
```

### NixOS (flakes)

```nix
{
  inputs.lolka.url = "github:<REPO>";

  outputs = { nixpkgs, lolka, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            lolka.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
```

Или через оверлей:

```nix
nixpkgs.overlays = [ lolka.overlays.default ];
environment.systemPackages = [ pkgs.lolka ];
```

## Примечания

- Библиотеки находятся через `RPATH`, который проставляет `autoPatchelfHook`.
  Обёртка намеренно не задаёт `LD_LIBRARY_PATH`: эта переменная утекала бы в
  дочерние процессы (`xdg-open` → `gio` → браузер) и заставляла бы их грузить
  glibc из флейка вместо собственной.
- Внешние ссылки (в том числе вход через браузер) открываются через `xdg-open`;
  `glib` добавлен в `PATH` обёртки, чтобы под GNOME/Wayland работал
  `gio open`.
- `chrome-sandbox` удаляется из бандла: копия в Nix store не может быть
  setuid-root, поэтому Chromium переключается на sandbox через user namespaces.
  Если приложение всё равно не стартует, добавьте `--no-sandbox` в флаги обёртки
  в `package.nix`.
- Нативные Node-аддоны для Windows и macOS остаются в архиве как есть.
  `autoPatchelf` игнорирует те, что не может удовлетворить.
- `.desktop`-файл и иконки hicolor устанавливаются в `$out/share`, строка `Exec`
  переписывается на обёрнутый бинарник `lolka`.
- Приложение при старте проверяет обновления на `https://cdn.lolka.app/electron`
  и создаёт главное окно только после завершения проверки (успешной или с
  ошибкой). `resources/package-type` удалять нельзя: он выбирает deb-апдейтер.
  Без него приложение переключается на `AppImageUpdater`, который без
  переменной `APPIMAGE` ничего не делает, и заставка висит вечно.

## Обновление

Версии и хеши хранятся в `sources.json`. Перегенерировать его можно так:

```sh
bash scripts/update.sh
```

Скрипт читает `latest-linux.yml` из бакета с релизами, предфетчит новый `.deb`
и перезаписывает `sources.json`. Workflow GitHub Actions
(`.github/workflows/update.yml`) запускает его раз в сутки, собирает пакет и
коммитит результат.
