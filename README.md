# 🔓 SiYuan Unlock Edition

> Кастомная сборка на базе [siyuan-note/siyuan](https://github.com/siyuan-note/siyuan)

## ✨ Что изменено

| Функция | Описание |
|---------|----------|
| **Разблокировка VIP** | Все VIP-функции доступны по умолчанию (облачная синхронизация, S3/WebDAV и др.) |
| **Отключение автообновления** | Автоматическая загрузка пакетов обновления отключена по умолчанию |
| **Поддержка Docker** | Автоматическая сборка multi-arch Docker-образов (amd64/arm64) |
| **Сборка Android** | Корректный pipeline: `gomobile bind` → `kernel.aar` → `.apk` |

## 🐳 Использование Docker

```bash
# Pull образа
docker pull ghcr.io/aatumaykin/unlock-siyuan:latest

# Запуск контейнера
docker run -d \
  -v /path/to/workspace:/siyuan/workspace \
  -p 6806:6806 \
  ghcr.io/aatumaykin/unlock-siyuan:latest \
  --workspace=/siyuan/workspace \
  --accessAuthCode=your_password
```

## 📥 Скачать

- [GitHub Releases](https://github.com/aatumaykin/unlock-siyuan/releases) — desktop (.dmg, .AppImage, .exe), Android (.apk), Docker
- [GitHub Container Registry](https://github.com/aatumaykin/unlock-siyuan/pkgs/container/unlock-siyuan) — Docker-образы

## 📱 Установка на Android

1. Скачайте `siyuan-vX.Y.Z-android.apk` из [Releases](https://github.com/aatumaykin/unlock-siyuan/releases)
2. Разрешите установку из неизвестных источников в настройках телефона
3. Установите APK
4. Для сборки конкретной версии: **Actions** → **Release Android** → **Run workflow** (укажите тег upstream, например `v3.6.5`)

## 🔄 Синхронизация с upstream

При появлении новой версии в `siyuan-note/siyuan`:

```bash
./scripts/sync-upstream.sh
```

Автоматическая проверка новых версий выполняется по cron (вт/пт) через workflow **Release Cron**.

## ⚙️ Настройка CI/CD (GitHub Actions)

### 📍 Где настраивать

**Settings** → **Secrets and variables** → **Actions**

### 🔐 Secrets (обязательно для Docker)

| Secret | Описание | Как получить |
|--------|----------|--------------|
| `DOCKER_USERNAME` | Логин Docker Hub | Ваш логин на [Docker Hub](https://hub.docker.com/) |
| `DOCKERHUB_TOKEN` | Access Token Docker Hub | [Создать токен](https://hub.docker.com/settings/security) |

> Для сборки desktop и Android secrets **не требуются** — используется встроенный `GITHUB_TOKEN`.

### 📝 Variables (опционально)

| Variable | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `IMAGE_NAME` | Имя Docker-образа | `siyuan` |

---

### 🚀 Workflow'ы

| Workflow | Триггер | Что делает |
|----------|---------|------------|
| **Desktop Release** | Tag / вручную | Linux (.tar.gz, .AppImage), macOS (.dmg Intel+ARM), Windows (.exe) |
| **Release Android** | Вручную | `gomobile bind` → `kernel.aar` → `.apk` |
| **Release Docker** | Tag / вручную | Multi-arch Docker → GHCR + Docker Hub |
| **Release Cron** | Cron (вт/пт) | Проверка новой версии upstream → автозапуск сборки |
| **Target Branch** | PR | Направляет новые PR в ветку `dev` |

### 📋 Ручной запуск сборки

1. **Actions** → выбрать нужный workflow
2. **Run workflow**
3. Указать параметры (для Android):
   - `version` — тег upstream (например `v3.6.5`)
   - `packageManager` — версия pnpm (например `pnpm@10.33.0`)

---

## 📁 Структура репозитория

```
├── .patches/              # Патчи к upstream
│   ├── 001-vip-bypass.patch          # return true в IsPaidUser/IsSubscriber
│   ├── 002-disable-auto-update.patch # DownloadInstallPkg: false
│   └── 003-custom-update-source.patch
├── scripts/               # Скрипты обслуживания
│   ├── apply-patches.sh              # Применение патчей
│   └── sync-upstream.sh              # Merge upstream + re-apply patches
├── .github/workflows/     # CI/CD
│   ├── desktop-release.yml           # Desktop (.dmg, .AppImage, .exe)
│   ├── release-android.yml           # Android (.apk)
│   ├── release-docker.yml            # Docker multi-arch
│   ├── release-cron.yml              # Автопроверка upstream
│   └── target-branch.yml             # PR → dev
├── README.md                          # Этот файл
└── ...                                # Исходники SiYuan (полное дерево upstream)
```

## 🔧 Архитектура сборки Android

```
upstream siyuan (tag)
  ├─ apply patches → kernel.aar (gomobile bind ./mobile/)
  ├─ build mobile UI → app.zip (appearance + guide + stage + changelogs)
  └─ siyuan-android (gradle)
       ├─ kernel.aar → app/libs/
       ├─ app.zip    → app/src/main/assets/
       └─ ./gradlew assembleOfficialRelease → siyuan.apk
```

## ⚠️ Отказ от ответственности

1. **Лицензия AGPL-3.0**: Проект распространяется под AGPL-3.0 — исходный код открыт
2. **Только для личного использования**: Сборка предназначена для личного изучения и использования
3. **Поддержите автора**: Если SiYuan вам полезен — рассмотрите [официальную подписку](https://b3log.org/siyuan/en/pricing.html)

## 📜 Исходный проект

- Сайт: https://b3log.org/siyuan/
- Репозиторий: https://github.com/siyuan-note/siyuan
- Лицензия: AGPL-3.0
