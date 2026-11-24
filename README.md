# rynek-platform

Repozytorium-parasol platformy **Rynek**: zbiera wszystkie repozytoria jako submoduły git i pozwala uruchomić całą aplikację jedną komendą. Nie zawiera kodu aplikacji, tylko Dockerfile'e, `docker-compose.yml` i workflow budujące obrazy.

## Dwa sposoby uruchomienia

### A. Docker Compose (osobny kontener na usługę)

Wymaga ok. 8 GB pamięci dla Dockera.

```bash
git clone --recurse-submodules https://github.com/marketplace-e-commerce-i-uslugi/rynek-platform.git
cd rynek-platform
docker compose up -d             # ściąga gotowe obrazy z ghcr.io
# albo: docker compose up -d --build   # buduje obrazy z kodu w submodułach
```

Aplikacja: <http://localhost:4200>, brama API: <http://localhost:8080> (Swagger poszczególnych serwisów: `docker compose` nie publikuje ich portów, bo ruch idzie przez bramę).

Przydatne zmienne (plik `.env` obok `docker-compose.yml`): `TAG` (tag obrazów, domyślnie `latest`), `REGISTRY`, `JAVA_TOOL_OPTIONS` (pamięć JVM serwisów, domyślnie `-Xmx256m`), `JWT_ENFORCE` (`true` włącza wymuszanie JWT w bramie).

### C. Jeden kontener all-in-one (demo)

Cała platforma w jednym obrazie: PostgreSQL, Redis, SeaweedFS, OpenSearch, brama, 16 serwisów i frontend pod `supervisord`.

```bash
docker run --rm -p 4200:4200 -p 8333:8333 -m 6g ghcr.io/marketplace-e-commerce-i-uslugi/rynek-demo
```

- Start trwa 1–3 minuty. Aplikacja: <http://localhost:4200>.
- Pamięć: po starcie ok. 4,5 GB (17 JVM po ok. 250 MB plus OpenSearch, PostgreSQL i reszta), dlatego `-m 6g`. Docker Desktop musi mieć przydzielone co najmniej tyle RAM-u.
- Porty 4200 i 8333 muszą być wolne (np. wyłącz lokalny `ng serve` i `rynek-infra`).
- Port `8333` jest potrzebny, bo przeglądarka ładuje pliki (zdjęcia, awatary) bezpośrednio z magazynu S3.
- Dane znikają razem z kontenerem. Żeby je zachować, dodaj `-v rynek-demo-data:/data`.
- Stan usług: `docker exec <kontener> supervisorctl -c /etc/supervisor/rynek.conf status`. Logi: `docker exec <kontener> tail -f /var/log/rynek/<usługa>.log` (np. `identity-service`, `postgres`, `opensearch`).
- Pamięć JVM serwisów: zmienna `RYNEK_JAVA_OPTS` (domyślnie `-Xmx160m` na serwis). Jeśli serwis się restartuje z `OutOfMemoryError`, zwiększ ją, np. `-e RYNEK_JAVA_OPTS="-Xmx256m -XX:+UseSerialGC -XX:TieredStopAtLevel=1"`, i dodaj pamięci kontenerowi.
- Demo nie jest środowiskiem produkcyjnym: bazy mają jawne hasła z `rynek-infra`, a e-mail, SMS, płatności i przewoźnik działają na symulatorach `sandbox`.

Obraz all-in-one buduje się z kodu: `docker build -f docker/demo.Dockerfile -t rynek-demo .` (kilkanaście minut za pierwszym razem).

## Pierwsze ustawienie repozytorium (jednorazowo)

1. W organizacji GitHub utwórz puste repozytorium `rynek-platform` (publiczne).
2. Sklonuj je i dodaj pliki z tego folderu.
3. Dodaj submoduły (w Git Bash): `bash scripts/add-submodules.sh`.
4. `git add -A && git commit -m "Szkielet rynek-platform" && git push`.
5. W *Settings → Actions → General* zostaw uprawnienia do zapisu pakietów dla `GITHUB_TOKEN` (workflow sam prosi o `packages: write`).
6. Po pierwszym przebiegu workflow *Obrazy Dockera* wejdź w *Packages* organizacji i ustaw widoczność każdego obrazu na **Public**, żeby `docker pull` działał bez logowania.

## Automatyczna aktualizacja

Po pushu do `main` w dowolnym repozytorium Rynku:

1. `notify-platform.yml` w tym repozytorium wysyła zdarzenie `repository_dispatch` do `rynek-platform`.
2. Workflow *Obrazy Dockera* podbija submoduły do najnowszych commitów, buduje obrazy i wypycha `:latest`.
3. Następny `docker run` / `docker compose pull` pobiera nowe obrazy. Obraz `rynek-demo` jest gotowy po kilkunastu minutach od pushu.

Dodatkowo workflow startuje co godzinę (zabezpieczenie na wypadek zgubionego zgłoszenia), a nowy przebieg zastępuje trwający.

**Ustawienie (jednorazowo):**

1. Utwórz *fine-grained personal access token* (GitHub → Settings → Developer settings). Właściciel zasobu: organizacja. Repozytorium: tylko `rynek-platform`. Uprawnienie: **Contents → Read and write** (wystarcza do wysłania `repository_dispatch`).
2. W organizacji: *Settings → Secrets and variables → Actions → New organization secret*, nazwa **`PLATFORM_DISPATCH_TOKEN`**, dostęp dla wszystkich repozytoriów (są publiczne).
3. Skopiuj `scripts/notify-platform.yml` do każdego repozytorium jako `.github/workflows/notify-platform.yml` (oprócz `rynek-platform`, żeby nie zapętlić zdarzeń) i wypchnij.
4. Jeśli `main` w `rynek-platform` ma ochronę gałęzi, pozwól botowi `github-actions` na push, bo krok „Podbij submoduły” commituje bezpośrednio do `main`.

Ręczna aktualizacja bez automatu: `git submodule update --remote && git add -A && git commit -m "Aktualizacja submodułów" && git push`.

Ograniczenie: obraz `rynek-demo` przebudowuje wszystkie jary przy każdej zmianie, więc trwa kilkanaście minut. Jeśli to będzie przeszkadzać, można go złożyć z gotowych obrazów serwisów.

## Układ

| Ścieżka | Zawartość |
|---|---|
| `docker-compose.yml` | wariant A: infrastruktura, brama, frontend i 16 serwisów |
| `docker/service.Dockerfile` | wspólny Dockerfile serwisów Spring Boot (kontekst: folder serwisu) |
| `docker/frontend.Dockerfile` | Angular za nginx (kontekst: `rynek-frontend`) |
| `docker/demo.Dockerfile`, `docker/demo/` | wariant C: obraz all-in-one |
| `scripts/add-submodules.sh` | dodaje 21 repozytoriów jako submoduły |
| `.github/workflows/images.yml` | buduje i publikuje obrazy w `ghcr.io` |

Kafka nie jest uruchamiana, bo serwisy jeszcze z niej nie korzystają.
