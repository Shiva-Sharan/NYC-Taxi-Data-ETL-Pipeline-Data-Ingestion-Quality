#!/usr/bin/env python
# coding: utf-8

# In[ ]:


import pandas as pd
from sqlalchemy import create_engine
from tqdm.auto import tqdm

prefix = 'https://github.com/DataTalksClub/nyc-tlc-data/releases/download/yellow/'
file_url = prefix + 'yellow_tripdata_2021-01.csv.gz'

# ---------- Step 1: Read sample to define schema ----------
dtype = {
    "VendorID": "Int64",
    "passenger_count": "Int64",
    "trip_distance": "float64",
    "RatecodeID": "Int64",
    "store_and_fwd_flag": "string",
    "PULocationID": "Int64",
    "DOLocationID": "Int64",
    "payment_type": "Int64",
    "fare_amount": "float64",
    "extra": "float64",
    "mta_tax": "float64",
    "tip_amount": "float64",
    "tolls_amount": "float64",
    "improvement_surcharge": "float64",
    "total_amount": "float64",
    "congestion_surcharge": "float64"
}

parse_dates = [
    "tpep_pickup_datetime",
    "tpep_dropoff_datetime"
]

df_sample = pd.read_csv(
    file_url,
    nrows=100,
    dtype=dtype,
    parse_dates=parse_dates
)

# ---------- Step 2: Create DB table ----------
engine = create_engine('postgresql://shivasharan:shiva@localhost:5432/ny_taxi')

df_sample.head(0).to_sql(
    name='yellow_taxi_data',
    con=engine,
    if_exists='replace',
    index=False
)

print("Table created")

# ---------- Step 3: Create iterator (ONCE) ----------
df_iter = pd.read_csv(
    file_url,
    dtype=dtype,
    parse_dates=parse_dates,
    chunksize=100000
)

# ---------- Step 4: Insert chunks ----------
for df_chunk in tqdm(df_iter, desc="Inserting rows"):
    df_chunk.to_sql(
        name='yellow_taxi_data',
        con=engine,
        if_exists='append',
        index=False
    )
    print("Inserted:", len(df_chunk))


# In[ ]:




