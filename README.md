# Ledgerline: personal ledger in Dart

Personal demo project. A command-line ledger written in **Dart** with its **own small HTTP service** (shelf, JSON-file storage). It is standalone: no other service or repo is needed.

**Tech:** Dart, command-line tool, args (CommandRunner), shelf, shelf_router, REST API design, API-key auth, JSON-file storage, CSV export, unit tests, `dart compile exe` for a single native binary.

## Usage
```bash
dart pub get
dart run bin/ledgerline.dart serve                      # terminal 1: starts the service on :7070
dart run bin/ledgerline.dart add --category salary --amount 900 --note "November pay"
dart run bin/ledgerline.dart add --category food --amount -12.5 --note lunch
dart run bin/ledgerline.dart list --category food
dart run bin/ledgerline.dart list --format csv --out ledger.csv
dart run bin/ledgerline.dart summary
dart test
dart compile exe bin/ledgerline.dart -o ledgerline
```
Config: `--url` or `LEDGERLINE_URL`, and `LEDGERLINE_KEY` (default `dev-key`, change it for anything real).

## Service endpoints
`GET /health` (open), `GET /entries?category=`, `POST /entries`, `DELETE /entries/<id>`, `GET /summary`. All except `/health` need the header `x-api-key`.

## Honest status
Written without running it. Run `dart analyze` and `dart test` first.

## Screens (design mockups, not recordings)
![ledgerline-1-cli](docs/ledgerline-1-cli.jpg)
