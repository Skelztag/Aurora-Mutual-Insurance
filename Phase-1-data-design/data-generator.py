"""
Aurora Mutual Insurance — Synthetic Data Generator
====================================================

Generates synthetic customer, policy, and claims data matching the
schema defined in schema-design.md / ddl-scripts.sql, and deliberately
plants the data quality issues designed for the Phase 3 governance
exercise.

Usage:
    python data-generator.py              # generate CSVs only (default)
    python data-generator.py --load       # also load into Azure SQL
                                           # (requires AURORA_SQL_CONN env var)

Design notes:
- A fixed random seed is used throughout for reproducibility — re-running
  this script produces identical data, which matters once we start
  writing DQ rules and dashboards against specific known rows.
- Data is generated as pandas DataFrames, saved to CSV for spot-checking,
  and only pushed to SQL if --load is passed and a connection string is
  available. Generation and loading are kept as separate steps on purpose.
"""

import argparse
import os
import random
from datetime import date, timedelta

import pandas as pd
from faker import Faker

SEED = 42
random.seed(SEED)
fake = Faker("en_GB")
Faker.seed(SEED)

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "data")
os.makedirs(OUTPUT_DIR, exist_ok=True)

DATE_START = date(2021, 1, 1)
DATE_END = date(2027, 12, 31)


# ---------------------------------------------------------------------
# dim_date
# ---------------------------------------------------------------------
def generate_dim_date():
    rows = []
    d = DATE_START
    while d <= DATE_END:
        rows.append({
            "date_key": int(d.strftime("%Y%m%d")),
            "full_date": d.isoformat(),
            "day": d.day,
            "month": d.month,
            "month_name": d.strftime("%B"),
            "quarter": (d.month - 1) // 3 + 1,
            "year": d.year,
            "is_weekend": d.weekday() >= 5,
        })
        d += timedelta(days=1)
    return pd.DataFrame(rows)


# ---------------------------------------------------------------------
# dim_product
# ---------------------------------------------------------------------
def generate_dim_product():
    return pd.DataFrame([
        {"product_id": 1, "product_name": "Motor",  "product_category": "Vehicle Insurance"},
        {"product_id": 2, "product_name": "Home",   "product_category": "Property Insurance"},
        {"product_id": 3, "product_name": "Travel", "product_category": "Travel Insurance"},
    ])


# ---------------------------------------------------------------------
# dim_branch
# ---------------------------------------------------------------------
def generate_dim_branch():
    branches = [
        ("Manchester Central", "North West"),
        ("Leeds City",         "Yorkshire"),
        ("Birmingham Hub",     "West Midlands"),
        ("London Bridge",      "London"),
        ("Bristol West",       "South West"),
        ("Glasgow North",      "Scotland"),
        ("Cardiff Bay",        "Wales"),
        ("Newcastle Quay",     "North East"),
        ("Nottingham East",    "East Midlands"),
        ("Southampton Coast",  "South East"),
    ]
    rows = []
    for i, (name, region) in enumerate(branches, start=1):
        rows.append({
            "branch_id": i,
            "branch_name": name,
            "region": region,
            "channel": random.choices(["Direct", "Broker"], weights=[0.6, 0.4])[0],
        })
    return pd.DataFrame(rows)


# ---------------------------------------------------------------------
# dim_customer
# ---------------------------------------------------------------------
CASING_VARIANTS = {
    "Standard": ["standard", "STANDARD", "Standard"],
    "Mutual Rewards": ["mutual rewards", "MUTUAL REWARDS", "Mutual Rewards"],
}


def _random_dob():
    age_years = random.randint(18, 85)
    return (date.today() - timedelta(days=age_years * 365 + random.randint(0, 364))).isoformat()


def _random_postcode(malformed=False):
    if malformed:
        # Deliberately broken formats: missing space, lowercase, digits-only, too short
        return random.choice([
            fake.postcode().replace(" ", "").lower(),
            "".join(c for c in fake.postcode() if c.isdigit()) or "00000",
            fake.postcode()[:3],
        ])
    return fake.postcode()


def generate_dim_customer(n_base=2940, n_duplicates=60):
    rows = []
    for cid in range(1, n_base + 1):
        segment = random.choices(["Standard", "Mutual Rewards"], weights=[0.72, 0.28])[0]
        missing_email = random.random() < 0.05
        missing_phone = random.random() < 0.05
        malformed_postcode = random.random() < 0.015
        inconsistent_casing = random.random() < 0.08

        segment_value = (
            random.choice(CASING_VARIANTS[segment]) if inconsistent_casing else segment
        )

        rows.append({
            "customer_id": cid,
            "first_name": fake.first_name(),
            "last_name": fake.last_name(),
            "date_of_birth": _random_dob(),
            "address_line1": fake.street_address().replace("\n", ", "),
            "address_line2": fake.secondary_address() if random.random() < 0.3 else None,
            "city": fake.city(),
            "postcode": _random_postcode(malformed=malformed_postcode),
            "email": None if missing_email else fake.email(),
            "phone_number": None if missing_phone else fake.phone_number(),
            "customer_segment": segment_value,
            "join_date": fake.date_between(start_date=DATE_START, end_date=DATE_END).isoformat(),
            "marketing_consent_flag": random.choices([1, 0], weights=[0.65, 0.35])[0],
        })

    df = pd.DataFrame(rows)

    # ---- Deliberate duplicate customers (~2% of the full ~3,000 book) ----
    # Simulates an unresolved system-migration merge: same person, new ID,
    # slightly different name spelling/casing or address formatting.
    dup_rows = []
    source_sample = df.sample(n=n_duplicates, random_state=SEED)
    next_id = n_base + 1
    for _, src in source_sample.iterrows():
        dup = src.copy()
        dup["customer_id"] = next_id
        # Introduce a small, realistic variation
        variation = random.choice(["name_case", "whitespace", "address_abbrev"])
        if variation == "name_case":
            dup["first_name"] = dup["first_name"].upper()
        elif variation == "whitespace":
            dup["last_name"] = f" {dup['last_name']} "
        else:
            dup["address_line1"] = dup["address_line1"].replace("Street", "St").replace("Road", "Rd")
        dup_rows.append(dup)
        next_id += 1

    df = pd.concat([df, pd.DataFrame(dup_rows)], ignore_index=True)
    return df


# ---------------------------------------------------------------------
# dim_policy
# ---------------------------------------------------------------------
PREMIUM_RANGES = {
    1: (300, 1200),   # Motor
    2: (150, 700),    # Home
    3: (20, 150),      # Travel
}
SUM_INSURED_RANGES = {
    1: (5000, 35000),
    2: (100000, 500000),
    3: (1000, 10000),
}


def generate_dim_policy(customers_df, n_policies=4500):
    # Mutual Rewards customers hold more policies — ties the schema back
    # to the segment definition in the company brief (2+ products = tier)
    weights = customers_df["customer_segment"].str.lower().str.strip().apply(
        lambda s: 2.2 if "mutual" in s else 1.0
    )
    chosen_customers = random.choices(
        customers_df["customer_id"].tolist(), weights=weights.tolist(), k=n_policies
    )

    rows = []
    for pid, cust_id in enumerate(chosen_customers, start=1):
        product_id = random.choices([1, 2, 3], weights=[0.5, 0.35, 0.15])[0]
        start = fake.date_between(start_date=DATE_START, end_date=date(2026, 6, 30))
        end = start + timedelta(days=365)
        status = random.choices(
            ["Active", "Lapsed", "Cancelled"], weights=[0.75, 0.15, 0.10]
        )[0]
        low, high = PREMIUM_RANGES[product_id]
        si_low, si_high = SUM_INSURED_RANGES[product_id]

        rows.append({
            "policy_id": pid,
            "customer_id": cust_id,
            "product_id": product_id,
            "branch_id": random.randint(1, 10),
            "policy_start_date": start.isoformat(),
            "policy_end_date": end.isoformat(),
            "status": status,
            "annual_premium": round(random.uniform(low, high), 2),
            "sum_insured": round(random.uniform(si_low, si_high), 2),
        })
    return pd.DataFrame(rows)


# ---------------------------------------------------------------------
# fact_claims
# ---------------------------------------------------------------------
CLAIM_TYPES = {
    1: ["Collision", "Theft", "Windscreen", "Fire"],
    2: ["Fire", "Water Damage", "Theft", "Storm Damage"],
    3: ["Medical", "Trip Cancellation", "Baggage Loss", "Flight Delay"],
}
CLAIM_AMOUNT_RANGES = {
    1: (200, 8000),
    2: (150, 25000),
    3: (50, 3000),
}
# Seasonality weight by month (1=Jan ... 12=Dec).
# Motor/Home skew winter (ice, storms); Travel skews summer (holidays).
SEASONALITY = {
    1: {1: 1.4, 2: 1.3, 3: 0.7},
    2: {1: 1.3, 2: 1.2, 3: 0.6},
    3: {1: 0.9, 2: 0.9, 3: 0.7},
    4: {1: 0.8, 2: 0.8, 3: 0.9},
    5: {1: 0.7, 2: 0.7, 3: 1.2},
    6: {1: 0.7, 2: 0.7, 3: 1.6},
    7: {1: 0.7, 2: 0.7, 3: 1.8},
    8: {1: 0.7, 2: 0.7, 3: 1.7},
    9: {1: 0.8, 2: 0.8, 3: 1.1},
    10: {1: 1.0, 2: 1.0, 3: 0.8},
    11: {1: 1.2, 2: 1.2, 3: 0.7},
    12: {1: 1.4, 2: 1.4, 3: 0.9},
}


def generate_fact_claims(policies_df, n_claims=800, orphan_rate=0.01, bad_date_rate=0.01):
    # Claims frequency isn't uniform across products — Motor claims most
    # often in real insurance books, so we weight selection accordingly
    # rather than sampling policies uniformly at random.
    product_weight = {1: 1.6, 2: 1.0, 3: 0.6}
    policies_df = policies_df.copy()
    policies_df["_weight"] = policies_df["product_id"].map(product_weight)

    chosen = policies_df.sample(
        n=n_claims, replace=True, weights=policies_df["_weight"], random_state=SEED
    ).reset_index(drop=True)

    rows = []
    for i, policy in chosen.iterrows():
        product_id = policy["product_id"]
        policy_start = date.fromisoformat(policy["policy_start_date"])
        policy_end = date.fromisoformat(policy["policy_end_date"])

        # Pick an incurred_date within the policy period, seasonally weighted
        span_days = (policy_end - policy_start).days
        candidate_dates = [policy_start + timedelta(days=d) for d in range(span_days)]
        month_weights = [SEASONALITY[dt.month][product_id] for dt in candidate_dates]
        incurred_date = random.choices(candidate_dates, weights=month_weights)[0]

        claim_status = random.choices(
            ["Paid", "Approved", "Open", "Rejected"], weights=[0.5, 0.2, 0.15, 0.15]
        )[0]

        settled_date = None
        if claim_status in ("Paid", "Approved"):
            settled_date = incurred_date + timedelta(days=random.randint(3, 45))

        low, high = CLAIM_AMOUNT_RANGES[product_id]

        rows.append({
            "claim_id": i + 1,
            "policy_id": policy["policy_id"],
            "customer_id": policy["customer_id"],
            "claim_date_key": int(incurred_date.strftime("%Y%m%d")),
            "claim_type": random.choice(CLAIM_TYPES[product_id]),
            "claim_status": claim_status,
            "claim_amount": round(random.uniform(low, high), 2),
            "incurred_date": incurred_date.isoformat(),
            "settled_date": settled_date.isoformat() if settled_date else None,
        })

    df = pd.DataFrame(rows)

    # ---- Deliberate orphaned claims (~1%) ----
    # policy_id points beyond the real range — simulates a broken ETL load.
    # FK constraint on fact_claims.policy_id is deferred (see ddl-scripts.sql
    # Stage 5) specifically so these rows can be loaded.
    max_policy_id = policies_df["policy_id"].max()
    n_orphans = max(1, int(len(df) * orphan_rate))
    orphan_idx = df.sample(n=n_orphans, random_state=SEED).index
    df.loc[orphan_idx, "policy_id"] = [
        max_policy_id + random.randint(1, 500) for _ in range(n_orphans)
    ]

    # ---- Deliberate illogical dates (~1%) ----
    # settled_date set before incurred_date — a temporal validity issue.
    settled_rows = df[df["settled_date"].notna()]
    n_bad_dates = max(1, int(len(settled_rows) * bad_date_rate))
    bad_idx = settled_rows.sample(n=n_bad_dates, random_state=SEED).index
    for idx in bad_idx:
        inc = date.fromisoformat(df.loc[idx, "incurred_date"])
        df.loc[idx, "settled_date"] = (inc - timedelta(days=random.randint(1, 10))).isoformat()

    return df.drop(columns=["policy_id"]).assign(policy_id=df["policy_id"])[
        ["claim_id", "policy_id", "customer_id", "claim_date_key", "claim_type",
         "claim_status", "claim_amount", "incurred_date", "settled_date"]
    ]


# ---------------------------------------------------------------------
# Spot-check summary — mirrors Phase 1 action 7: "spot-check the data
# for realism (claim ratios, seasonality, product mix)"
# ---------------------------------------------------------------------
def spot_check(customers, policies, claims, products):
    print("\n=== SPOT CHECK SUMMARY ===")
    print(f"Customers: {len(customers)} rows "
          f"(missing email: {customers['email'].isna().mean():.1%}, "
          f"missing phone: {customers['phone_number'].isna().mean():.1%})")
    print(f"Policies:  {len(policies)} rows")
    print(f"Claims:    {len(claims)} rows")

    prod_lookup = products.set_index("product_id")["product_name"]
    print("\nPolicy product mix:")
    print((policies["product_id"].map(prod_lookup).value_counts(normalize=True) * 100).round(1))

    print("\nClaims by product (claim frequency check):")
    claims_with_product = claims.merge(
        policies[["policy_id", "product_id"]], on="policy_id", how="left"
    )
    print((claims_with_product["product_id"].map(prod_lookup)
           .value_counts(normalize=True) * 100).round(1))

    print("\nClaims by month (seasonality check):")
    claim_months = pd.to_datetime(claims["incurred_date"]).dt.month
    print(claim_months.value_counts().sort_index())

    n_orphans = (~claims["policy_id"].isin(policies["policy_id"])).sum()
    n_bad_dates = (
        pd.to_datetime(claims["settled_date"], errors="coerce") <
        pd.to_datetime(claims["incurred_date"])
    ).sum()
    print(f"\nOrphaned claims (policy_id not in dim_policy): {n_orphans} "
          f"({n_orphans/len(claims):.1%})")
    print(f"Illogical dates (settled before incurred): {n_bad_dates}")
    print("===========================\n")


# ---------------------------------------------------------------------
# Optional: load into Azure SQL
# ---------------------------------------------------------------------
def load_to_sql(tables: dict, conn_string: str):
    # pyodbc/sqlalchemy imported here, not at module level, so the script
    # still runs for CSV generation on machines without an ODBC driver
    # installed.
    from sqlalchemy import create_engine

    engine = create_engine(conn_string)
    load_order = ["dim_date", "dim_product", "dim_branch", "dim_customer",
                   "dim_policy", "fact_claims"]
    for name in load_order:
        tables[name].to_sql(name, engine, if_exists="append", index=False, chunksize=500)
        print(f"Loaded {len(tables[name])} rows into {name}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--load", action="store_true",
                         help="Load into Azure SQL after generating (requires AURORA_SQL_CONN)")
    args = parser.parse_args()

    dim_date = generate_dim_date()
    dim_product = generate_dim_product()
    dim_branch = generate_dim_branch()
    dim_customer = generate_dim_customer()
    dim_policy = generate_dim_policy(dim_customer)
    fact_claims = generate_fact_claims(dim_policy)

    tables = {
        "dim_date": dim_date,
        "dim_product": dim_product,
        "dim_branch": dim_branch,
        "dim_customer": dim_customer,
        "dim_policy": dim_policy,
        "fact_claims": fact_claims,
    }

    for name, df in tables.items():
        path = os.path.join(OUTPUT_DIR, f"{name}.csv")
        df.to_csv(path, index=False)
        print(f"Wrote {len(df)} rows -> {path}")

    spot_check(dim_customer, dim_policy, fact_claims, dim_product)

    if args.load:
        conn_string = os.environ.get("AURORA_SQL_CONN")
        if not conn_string:
            raise SystemExit(
                "AURORA_SQL_CONN environment variable not set. "
                "Set it to a SQLAlchemy connection string for the Azure SQL Database."
            )
        load_to_sql(tables, conn_string)


if __name__ == "__main__":
    main()
