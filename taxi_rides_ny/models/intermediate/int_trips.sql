with unioned as (
    select 
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
        payment_type
    from {{ ref("int_trips_unionall") }}

    -- 🔥 IMPORTANT: filter early if possible
    -- where pickup_datetime >= '2023-01-01'
),

payment as (
    select 
        payment_type,
        description
    from {{ ref('payment_type_lookup') }}
),

deduplicated as (
    select *
    from unioned
    qualify row_number() over (
        partition by vendor_id, pickup_datetime, pickup_locationid, ratecode_id
        order by dropoff_datetime
    ) = 1
),

cleaned_and_enriched as (
    select
        {{ dbt_utils.generate_surrogate_key([
            'd.vendor_id',
            'd.pickup_datetime',
            'd.pickup_locationid',
            'd.ratecode_id'
        ]) }} as trip_id,

        d.vendor_id,
        d.ratecode_id,
        d.pickup_locationid,
        d.dropoff_locationid,
        d.pickup_datetime,
        d.dropoff_datetime,
        d.store_and_fwd_flag,
        d.passenger_count,
        d.trip_distance,
        d.trip_type,
        d.fare_amount,
        d.extra,
        d.mta_tax,
        d.tip_amount,
        d.tolls_amount,
        d.ehail_fee,
        d.improvement_surcharge,
        d.total_amount,

        coalesce(d.payment_type, 0) as payment_type,
        coalesce(pt.description, 'Unknown') as payment_type_description

    from deduplicated d
    left join payment pt
        on coalesce(d.payment_type, 0) = pt.payment_type
)

select * from cleaned_and_enriched