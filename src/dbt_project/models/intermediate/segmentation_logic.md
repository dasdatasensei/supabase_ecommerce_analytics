# Olist E-commerce Segmentation Logic

This document details the business logic and rationale behind the segmentation strategies used in our intermediate models.

## Customer Segmentation

### Frequency Segmentation

```sql
case
    when total_orders >= 5 then 'high_frequency'
    when total_orders >= 2 then 'medium_frequency'
    else 'low_frequency'
end as frequency_segment
```

- **High Frequency** (5+ orders): Represents loyal customers who regularly shop on the platform
- **Medium Frequency** (2-4 orders): Represents returning customers showing potential for increased engagement
- **Low Frequency** (1 order): Represents one-time buyers who need activation strategies

### Value Segmentation

```sql
case
    when avg_order_amount >= 500 then 'high_value'
    when avg_order_amount >= 100 then 'medium_value'
    else 'low_value'
end as value_segment
```

- **High Value** (500+ BRL): Premium customers with significant spending power
- **Medium Value** (100-499 BRL): Core customer base with moderate spending
- **Low Value** (<100 BRL): Price-sensitive customers or small item purchasers

### NPS Segmentation

```sql
case
    when avg_review_score >= 4 then 'promoter'
    when avg_review_score >= 3 then 'passive'
    else 'detractor'
end as nps_segment
```

- **Promoter** (4-5 stars): Brand advocates likely to recommend
- **Passive** (3-3.9 stars): Satisfied but not enthusiastic customers
- **Detractor** (<3 stars): At-risk customers requiring immediate attention

## Seller Segmentation

### Volume Segmentation

```sql
case
    when total_orders >= 100 then 'high_volume'
    when total_orders >= 20 then 'medium_volume'
    else 'low_volume'
end as volume_segment
```

- **High Volume** (100+ orders): Power sellers driving significant platform activity
- **Medium Volume** (20-99 orders): Established sellers with steady business
- **Low Volume** (<20 orders): New or occasional sellers

### Value Segmentation

```sql
case
    when total_gmv >= 50000 then 'high_value'
    when total_gmv >= 10000 then 'medium_value'
    else 'low_value'
end as value_segment
```

- **High Value** (50,000+ BRL): Strategic sellers generating significant revenue
- **Medium Value** (10,000-49,999 BRL): Growing sellers with good potential
- **Low Value** (<10,000 BRL): Small-scale or new sellers

### Performance Segmentation

```sql
case
    when avg_review_score >= 4.5 then 'excellent'
    when avg_review_score >= 4.0 then 'good'
    when avg_review_score >= 3.0 then 'average'
    else 'poor'
end as performance_segment
```

- **Excellent** (4.5+ stars): Top-performing sellers exceeding customer expectations
- **Good** (4.0-4.4 stars): Reliable sellers with consistent quality
- **Average** (3.0-3.9 stars): Sellers meeting basic expectations
- **Poor** (<3.0 stars): Underperforming sellers requiring intervention

### Delivery Segmentation

```sql
case
    when on_time_delivery_rate >= 95 then 'excellent'
    when on_time_delivery_rate >= 85 then 'good'
    when on_time_delivery_rate >= 70 then 'average'
    else 'poor'
end as delivery_segment
```

- **Excellent** (95%+ on-time): Outstanding logistics performance
- **Good** (85-94% on-time): Reliable delivery service
- **Average** (70-84% on-time): Meeting minimum standards
- **Poor** (<70% on-time): Requires immediate improvement

## Product Segmentation

### Volume Segmentation

```sql
case
    when total_orders >= 50 then 'high_volume'
    when total_orders >= 10 then 'medium_volume'
    else 'low_volume'
end as volume_segment
```

- **High Volume** (50+ orders): Best-selling products
- **Medium Volume** (10-49 orders): Steady performers
- **Low Volume** (<10 orders): Slow-moving inventory

### Price Segmentation

```sql
case
    when avg_price >= 500 then 'premium'
    when avg_price >= 100 then 'mid_range'
    else 'budget'
end as price_segment
```

- **Premium** (500+ BRL): High-end products with higher margins
- **Mid-range** (100-499 BRL): Core product offerings
- **Budget** (<100 BRL): Entry-level or promotional items

### Rating Segmentation

```sql
case
    when avg_review_score >= 4.5 then 'excellent'
    when avg_review_score >= 4.0 then 'good'
    when avg_review_score >= 3.0 then 'average'
    else 'poor'
end as rating_segment
```

- **Excellent** (4.5+ stars): Top-rated products
- **Good** (4.0-4.4 stars): Well-received products
- **Average** (3.0-3.9 stars): Satisfactory products
- **Poor** (<3.0 stars): Products needing improvement

### Physical Attributes Segmentation

#### Weight Segmentation

```sql
case
    when weight_g >= 10000 then 'heavy'
    when weight_g >= 2000 then 'medium'
    else 'light'
end as weight_segment
```

- **Heavy** (10kg+): Requires special handling
- **Medium** (2-10kg): Standard shipping
- **Light** (<2kg): Economic shipping

#### Size Segmentation

```sql
case
    when volume_cm3 >= 50000 then 'large'
    when volume_cm3 >= 10000 then 'medium'
    else 'small'
end as size_segment
```

- **Large** (50,000+ cm³): Requires special storage/shipping
- **Medium** (10,000-49,999 cm³): Standard handling
- **Small** (<10,000 cm³): Easy to store/ship

## Business Applications

### Customer Strategy

- Combine frequency and value segments for targeted marketing
- Use NPS segments for retention and satisfaction improvement
- Target high-frequency, high-value promoters for loyalty programs

### Seller Strategy

- Focus resources on high-volume, high-value sellers
- Provide support to improve poor performers
- Use delivery segments for logistics optimization

### Product Strategy

- Use volume and rating segments for inventory decisions
- Leverage price segments for promotional planning
- Consider physical segments for logistics optimization

## Monitoring and Updates

The segmentation thresholds should be reviewed quarterly and adjusted based on:

- Overall business growth
- Market conditions
- Seasonal variations
- Regional differences
- Category-specific patterns

## Implementation Notes

1. All segmentation logic is implemented in the intermediate models
2. Segments are used as dimensions in downstream mart models
3. Regular monitoring of segment distributions is recommended
4. Thresholds may need adjustment based on business growth
