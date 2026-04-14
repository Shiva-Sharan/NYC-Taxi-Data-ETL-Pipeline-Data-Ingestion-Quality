# NYC Taxi Data ETL Pipeline — Data Ingestion & Quality

An end-to-end data engineering project that ingests NYC Yellow and Green Taxi trip data, loads it into a PostgreSQL database, transforms it with **dbt** (using DuckDB as the analytical engine), and orchestrates everything with **Kestra**.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Modules](#modules)
  - [1. Pipeline — Data Ingestion](#1-pipeline--data-ingestion)
  - [2. taxi\_rides\_ny — dbt Transformations](#2-taxi_rides_ny--dbt-transformations)
  - [3. Workflow — Kestra Orchestration](#3-workflow--kestra-orchestration)
  - [4. Test — Utilities](#4-test--utilities)
- [dbt Data Model Layers](#dbt-data-model-layers)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [1. Start Infrastructure](#1-start-infrastructure)
  - [2. Run Data Ingestion](#2-run-data-ingestion)
  - [3. Run dbt Transformations](#3-run-dbt-transformations)
- [Data Sources](#data-sources)
- [Data Quality](#data-quality)

---

## Project Overview

This project builds a complete ETL (Extract, Transform, Load) pipeline for **NYC Taxi trip data** covering Yellow and Green cab rides for the years **2019 and 2020**. It demonstrates:

- **Data Ingestion**: Downloading raw CSV data from GitHub and bulk-loading it into PostgreSQL in chunks.
- **Data Transformation & Quality**: Using **dbt** with **DuckDB** to clean, deduplicate, enrich, and model the data into analytics-ready tables.
- **Orchestration**: Using **Kestra** to schedule and manage the pipeline end-to-end.
- **Containerisation**: All services (PostgreSQL, pgAdmin, Kestra) are managed via **Docker Compose**.

---

## Architecture

```
Raw CSV Data (GitHub)
        │
        ▼
┌─────────────────────┐
│  Data Ingestion     │  ingest_data.py / ingest.py
│  (Python + Pandas)  │  Downloads CSV → Parquet → DuckDB
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│   PostgreSQL DB     │  ny_taxi database
│   (Docker)          │  yellow_taxi_data table
└────────┬────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│                   dbt (DuckDB)                      │
│                                                     │
│  Staging  →  Intermediate  →  Marts                 │
│  (clean)     (union + dedupe)  (facts + dims)       │
└────────┬────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────┐
│   Kestra            │  Workflow orchestration
│   (Docker)          │  Scheduling & monitoring
└─────────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Python 3.13 |
| Data processing | Pandas, PyArrow |
| Database | PostgreSQL 18 |
| Analytical engine | DuckDB |
| Transformations | dbt (with dbt-utils, codegen) |
| Orchestration | Kestra v1.1 |
| Containerisation | Docker & Docker Compose |
| Package management | uv |
| DB admin UI | pgAdmin 4 |

---

## Project Structure

```
.
├── pipeline/                  # Data ingestion module
│   ├── ingest_data.py         # Downloads CSV and loads into PostgreSQL in chunks
│   ├── pipeline.py            # Simple pipeline runner (outputs Parquet files)
│   ├── main.py                # Entry point
│   ├── Dockerfile             # Containerised ingestion
│   ├── docker-compose.yaml    # PostgreSQL + pgAdmin services
│   ├── pyproject.toml         # Python dependencies (uv)
│   └── notebook.ipynb         # Exploratory notebook
│
├── taxi_rides_ny/             # dbt project
│   ├── dbt_project.yml        # dbt project configuration
│   ├── ingest.py              # Downloads CSV.gz → Parquet → DuckDB tables
│   ├── models/
│   │   ├── staging/           # Source cleaning models
│   │   ├── intermediate/      # Union + deduplication models
│   │   └── marts/             # Fact & dimension tables + reporting
│   ├── macros/                # Custom Jinja macros
│   ├── seeds/                 # Static lookup CSVs (zones, payment types)
│   └── tests/                 # dbt data quality tests
│
├── workflow/                  # Kestra orchestration
│   ├── docker-compose.yaml    # Full stack: PostgreSQL + pgAdmin + Kestra
│   └── flows                  # Kestra flow definitions
│
└── test/                      # Utility scripts and sample files
    ├── script.py
    ├── file1.txt / file2.txt / file3.txt
```

---

## Modules

### 1. Pipeline — Data Ingestion

**Location**: `pipeline/`

Downloads NYC Yellow Taxi trip data from the [DataTalksClub dataset mirror](https://github.com/DataTalksClub/nyc-tlc-data) and loads it into a PostgreSQL database.

- Uses **Pandas** with chunked reading (`chunksize=100_000`) to handle large files without exhausting memory.
- Connects to PostgreSQL via **SQLAlchemy**.
- Tracks progress with **tqdm**.
- Packaged as a **Docker image** for portable, repeatable ingestion.

Key file: `pipeline/ingest_data.py`

```bash
# Run ingestion directly
uv run python ingest_data.py

# Or with Docker
docker build -t nyc-taxi-ingest .
docker run --network=host nyc-taxi-ingest
```

### 2. taxi\_rides\_ny — dbt Transformations

**Location**: `taxi_rides_ny/`

A full **dbt project** that transforms raw taxi data into analytics-ready models using **DuckDB** as the execution engine.

**`ingest.py`** — Downloads Yellow and Green taxi CSV.gz files for 2019–2020, converts them to Parquet, and loads them into DuckDB as `prod.yellow_tripdata` and `prod.green_tripdata`.

```bash
python ingest.py
dbt deps
dbt run
dbt test
```

### 3. Workflow — Kestra Orchestration

**Location**: `workflow/`

Provides a full-stack **Docker Compose** setup that spins up:

- **PostgreSQL** — main data warehouse (port `5432`)
- **pgAdmin** — database administration UI (port `8085`)
- **Kestra** — workflow orchestration platform (ports `8080` / `8081`)

```bash
cd workflow
docker compose up -d
```

Access Kestra UI at `http://localhost:8080` (credentials: `admin@kestra.io` / `Shiva1234`).

### 4. Test — Utilities

**Location**: `test/`

Contains utility scripts used during development:

- `script.py` — Lists files in the current directory and prints their content (useful for Docker volume testing).
- `file1.txt`, `file2.txt`, `file3.txt` — Sample data files.

---

## dbt Data Model Layers

```
Sources (DuckDB: prod.yellow_tripdata, prod.green_tripdata)
    │
    ▼
Staging
├── stg_yellow_tripdata   — Cast and rename Yellow cab columns
└── stg_green_tripdat     — Cast and rename Green cab columns
    │
    ▼
Intermediate
├── int_trips_unionall    — UNION ALL of Yellow + Green trips
└── int_trips             — Deduplication + payment enrichment + surrogate key generation
    │
    ▼
Marts
├── fct_trips             — Incremental fact table with zone + borough enrichment
├── dim_zones             — Taxi zone dimension (from seed: taxi_zone_lookup.csv)
├── dim_vendors           — Vendor dimension with descriptive vendor names
└── reporting/
    └── monthly_revenue_per_location  — Aggregated revenue report by location
```

### Seeds (Static Lookup Data)

| Seed | Description |
|---|---|
| `taxi_zone_lookup.csv` | Maps location IDs to borough, zone, and service zone |
| `payment_type_lookup.csv` | Maps payment type codes to human-readable descriptions |

### Custom Macros

| Macro | Description |
|---|---|
| `get_trip_duration_minutes` | Calculates trip duration in minutes from pickup and dropoff timestamps |
| `get_vendor_data` | Returns vendor name based on vendor ID |
| `init_duckdb` | Initialises DuckDB schema on `dbt run-start` |

---

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/)
- [Python 3.13+](https://www.python.org/)
- [uv](https://github.com/astral-sh/uv) (Python package manager)
- [dbt-duckdb](https://github.com/dbt-labs/dbt-duckdb)

### 1. Start Infrastructure

```bash
cd workflow
docker compose up -d
```

Services available after startup:

| Service | URL | Credentials |
|---|---|---|
| PostgreSQL | `localhost:5432` | `shivasharan` / `shiva` |
| pgAdmin | `http://localhost:8085` | `admin@admin.com` / `root` |
| Kestra | `http://localhost:8080` | `admin@kestra.io` / `Shiva1234` |

### 2. Run Data Ingestion

**Option A — Direct Python (into PostgreSQL):**

```bash
cd pipeline
uv sync
uv run python ingest_data.py
```

**Option B — Docker:**

```bash
cd pipeline
docker build -t nyc-taxi-ingest .
docker run --network=host nyc-taxi-ingest
```

**Option C — Download to DuckDB (for dbt):**

```bash
cd taxi_rides_ny
pip install duckdb requests
python ingest.py
```

### 3. Run dbt Transformations

```bash
cd taxi_rides_ny
dbt deps        # Install dbt packages (dbt_utils, codegen)
dbt seed        # Load lookup CSV files
dbt run         # Build all models
dbt test        # Run data quality tests
```

---

## Data Sources

All data comes from the [DataTalksClub NYC TLC Data mirror](https://github.com/DataTalksClub/nyc-tlc-data):

- **Yellow Taxi** trips — January 2021 (ingestion pipeline), 2019–2020 (dbt project)
- **Green Taxi** trips — 2019–2020 (dbt project)

Original data from the [NYC Taxi & Limousine Commission (TLC)](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page).

---

## Data Quality

The dbt project includes the following data quality measures:

- **Source filtering**: Records with a null `vendorID` are excluded at the staging layer.
- **Deduplication**: Duplicate trips (same vendor, pickup datetime, location, and rate code) are removed in the intermediate layer using `ROW_NUMBER()`.
- **Surrogate key generation**: A unique `trip_id` is generated per trip using `dbt_utils.generate_surrogate_key`.
- **Null handling**: Payment type nulls are coerced to `0` (Unknown) and joined to the payment lookup table.
- **Incremental loading**: The `fct_trips` fact table uses an incremental append strategy to process only the previous day's data on each run, keeping builds fast.
- **dbt tests**: Schema tests are defined to validate primary keys, accepted values, and referential integrity.