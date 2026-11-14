[English](README.md) | Русский

# lolka.nix

Nix flake с пакетом [Lolka](https://lolka.app) — приложением для чата и
голосового общения.

Пакет перепаковывает официальный готовый `.deb`, на который указывает лента
релизов `https://updates.lolka.app/desktop/linux/latest`. Публичных исходников
нет, поэтому сборка из исходников в песочнице Nix невозможна.

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
- В бандле лежат собственные Qt 6, FFmpeg, ICU и ONNX Runtime. Из nixpkgs через
  `autoPatchelfHook` берутся только системные библиотеки, которые они
  линкуют; `$ORIGIN`-пути сохраняются, чтобы приложение и его плагины находили
  библиотеки из бандла.
- `.desktop`-файл и иконки hicolor устанавливаются в `$out/share`, строка `Exec`
  переписывается на обёрнутый бинарник `lolka` (upstream использует `lolka-x`).
  Там же регистрируется MIME-тип `x-scheme-handler/lolka`, чтобы ссылки
  `lolka://` (их использует колбэк входа через браузер) открывали приложение;
  для этого нужна среда с поддержкой MIME-обработчиков.
- `$out/opt/lolka-x/package-type` остаётся на месте: он сообщает приложению,
  из какого канала обновлений оно установлено.

## Обновление

Версии и хеши хранятся в `sources.json`. Перегенерировать его можно так:

```sh
python3 scripts/update.py

# Принудительно обновляет хеши, даже если версия не изменилась
python3 scripts/update.py --force

# Использует nix store prefetch-file для генерации хеша
python3 scripts/update.py --nix-hash
```
