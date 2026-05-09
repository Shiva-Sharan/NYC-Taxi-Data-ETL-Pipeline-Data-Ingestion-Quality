{{
  config(
    materialized='incremental',
    incremental_strategy='append',
    on_schema_change='append_new_columns'
  )
}}

with trips as (

    select
        trip_id,
        vendor_id,
        ratecode_id,
        pickup_locationid,
        dropoff_locationid,
        pickup_datetime,
        dropoff_datetime,
        store_and_fwd_flag,
        passenger_count,
        trip_distance,
        trip_type,
        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        ehail_fee,
        improvement_surcharge,
        total_amount,
        payment_type,
        payment_type_description

    from {{ ref('int_trips') }}

    {% if is_incremental() %}
        -- 🔥 ONLY process yesterday's data (VERY SMALL)
        where pickup_datetime >= date_trunc('day', current_date - interval '1 day')
          and pickup_datetime < date_trunc('day', current_date)
    {% endif %}

),

zones as (
    select location_id, borough, zone
    from {{ ref('dim_zones') }}
)

select
    t.trip_id,
    t.vendor_id,
    t.ratecode_id,

    t.pickup_locationid,
    pz.borough as pickup_borough,
    pz.zone as pickup_zone,

    t.dropoff_locationid,
    dz.borough as dropoff_borough,
    dz.zone as dropoff_zone,

    t.pickup_datetime,
    t.dropoff_datetime,
    t.store_and_fwd_flag,

    t.passenger_count,
    t.trip_distance,
    t.trip_type,
    {{ get_trip_duration_minutes('t.pickup_datetime', 't.dropoff_datetime') }} as trip_duration_minutes,

    t.fare_amount,
    t.extra,
    t.mta_tax,
    t.tip_amount,
    t.tolls_amount,
    t.ehail_fee,
    t.improvement_surcharge,
    t.total_amount,
    t.payment_type,
    t.payment_type_description

from trips t
left join zones pz
    on t.pickup_locationid = pz.location_id
left join zones dz
    on t.dropoff_locationid = dz.location_id