# Deployment JutroWybory (VPS + Docker)

Aplikacja jest gotowa do wdrożenia na `jutrowybory.pl` przez Docker Compose:
Postgres + aplikacja Phoenix (release) + Caddy (automatyczny HTTPS).

## Wymagania

- VPS z publicznym IP (min. 1 GB RAM), system Linux (np. Ubuntu 24.04)
- Docker + plugin Compose
- Domena `jutrowybory.pl` wskazująca na IP serwera

## 1. DNS

W panelu domeny ustaw rekordy:

```
A     jutrowybory.pl      -> <IP serwera>
A     www.jutrowybory.pl  -> <IP serwera>   (opcjonalnie)
```

Poczekaj, aż rekord się rozpropaguje (`ping jutrowybory.pl`).

## 2. Przygotowanie serwera

**Uwaga:** domena obecnie coś hostuje — na serwerze prawdopodobnie działa
już nginx/Apache na portach 80/443. Zatrzymaj go, bo Caddy potrzebuje
tych portów do wystawienia certyfikatu HTTPS:

```bash
sudo systemctl stop nginx apache2 2>/dev/null
sudo systemctl disable nginx apache2 2>/dev/null
```

(Logo jest już w repo — `priv/static/images/image.png` — więc aplikacja
jest samowystarczalna i starego serwera nie trzeba utrzymywać.)

Zainstaluj Dockera:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER   # przeloguj się po tym
docker compose version          # powinno wypisać wersję pluginu
```

## 3. Skopiuj kod na serwer

Opcja A — git:

```bash
git clone <adres-repo> jutrowybory && cd jutrowybory
```

Opcja B — rsync z lokalnego komputera:

```bash
rsync -avz --exclude _build --exclude deps --exclude .git \
  /Users/zervis/jutrowybory/ user@<IP-serwera>:jutrowybory/
```

## 4. Konfiguracja (.env)

```bash
cd jutrowybory
cp .env.example .env
```

Wygeneruj sekret (lokalnie: `mix phx.gen.secret`, albo na serwerze:
`openssl rand -base64 48`) i uzupełnij `.env`:

```
POSTGRES_PASSWORD=<długie-losowe-hasło>
SECRET_KEY_BASE=<wynik-mix-phx.gen.secret>
PHX_HOST=jutrowybory.pl
```

## 5. Budowa i start

**Buduj na serwerze** (obraz z Maca ARM nie zadziała na serwerze x86 —
jeśli musisz budować lokalnie, użyj
`docker buildx build --platform linux/amd64 -t jutrowybory .` i wypchnij obraz):

```bash
docker compose up -d --build
```

Pierwszy build zajmuje kilka minut. Migracje bazy wykonują się
automatycznie przy starcie (`/app/bin/migrate`).

## 6. Dane początkowe + konto admina

```bash
docker compose exec app bin/jutrowybory eval "Jutrowybory.Release.seed()"
```

Seed tworzy: 10 tematów, ~33 pytania, konto admina
`admin@jutrowybory.pl` / `adminadmin12` oraz 8 kont demo z przykładowymi
odpowiedziami i komentarzami.

**Po pierwszym zalogowaniu zmień hasło admina**
(/users/settings). Jeśli nie chcesz danych demo na produkcji,
przed seedem usuń z `priv/repo/seeds.exs` sekcję kont demo — albo zamiast
seedu stwórz tylko admina ręcznie:

```bash
docker compose exec -it app bin/jutrowybory remote
```

```elixir
{:ok, u} = Jutrowybory.Accounts.register_user(%{email: "admin@jutrowybory.pl", password: "..."})
u |> Ecto.Changeset.change(role: "admin") |> Jutrowybory.Repo.update!()
```

## 7. Weryfikacja i logi

```bash
docker compose ps            # wszystkie 3 usługi: running/healthy
docker compose logs -f app   # logi aplikacji
curl -I https://jutrowybory.pl
```

Caddy sam pobierze certyfikat Let's Encrypt przy pierwszym żądaniu HTTPS
(wymaga otwartych portów 80/443 w firewallu):

```bash
sudo ufw allow 80,443/tcp
```

## Aktualizacja aplikacji

```bash
git pull            # albo ponowny rsync
docker compose up -d --build
```

Migracje wykonają się ponownie przy starcie (są idempotentne).

## Backup bazy

```bash
docker compose exec db pg_dump -U jutrowybory jutrowybory_prod > backup.sql
```

## Struktura plików deployowych

- `Dockerfile` — multi-stage build release'u Phoenix
- `docker-compose.yml` — db + app + caddy
- `Caddyfile` — reverse proxy `jutrowybory.pl -> app:4000`
- `.env.example` — szablon zmiennych środowiskowych
- `lib/jutrowybory/release.ex` — `migrate/0`, `seed/0` do użycia z `bin/jutrowybory eval`
