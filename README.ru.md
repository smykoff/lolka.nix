[English](README.md) | Русский

# lolka.nix

Nix flake с пакетом [Lolka](https://lolka.app) — Electron-приложением для
голосового чата и демонстрации экрана.

Пакет перепаковывает официальный готовый `.deb` из
`https://cdn.lolka.app/electron`. Публичных исходников нет, поэтому сборка из
исходников в песочнице Nix невозможна.

## Поддерживаемые платформы

| Система        | Статус    |
|----------------|-----------|
| `x86_64-linux` | проверено |

Upstream собирает пакеты только под Linux x86_64, поэтому другие системы не
объявлены.

## Использование

Нужны включённые flakes.

Запуск без установки:

```sh
nix run github:smykoff/lolka.nix
```

Установка в профиль пользователя:

```sh
nix profile install github:smykoff/lolka.nix
```

Чтобы обновить закреплённый `nixpkgs` в локальном клоне:

```sh
nix flake update
```

### NixOS (flakes)

```nix
{
  inputs.lolka.url = "github:smykoff/lolka.nix";

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
  `autoPatchelfIgnoreMissingDeps = [ "*" ]` не даёт `autoPatchelfHook` упасть на
  них; обратная сторона — реально отсутствующие Linux-библиотеки тоже не
  репортятся, поэтому при ошибках загрузки модулей смотрите `nix log`.
- `.desktop`-файл и иконки hicolor устанавливаются в `$out/share`, строка `Exec`
  переписывается на обёрнутый бинарник `lolka`. Там же регистрируется MIME-тип
  `x-scheme-handler/lolka`, чтобы ссылки `lolka://` (их использует колбэк входа
  через браузер) открывали приложение; для этого нужна среда с поддержкой
  MIME-обработчиков.
- Приложение при старте проверяет обновления на `https://cdn.lolka.app/electron`
  и создаёт главное окно только после завершения проверки (успешной или с
  ошибкой). `resources/package-type` удалять нельзя: он выбирает deb-апдейтер.
  Без него приложение переключается на `AppImageUpdater`, который без
  переменной `APPIMAGE` ничего не делает, и заставка висит вечно.

## Обновление

Версии и хеши хранятся в `sources.json`. Перегенерировать его можно так:

```sh
python3 -m venv scripts/.venv
scripts/.venv/bin/pip install pyyaml
scripts/.venv/bin/python scripts/update.py

# Принудительно обновляет хеши, даже если версия не изменилась
scripts/.venv/bin/python scripts/update.py --force

# Использует nix store prefetch-file для генерации хеша
scripts/.venv/bin/python scripts/update.py --nix-hash
```
