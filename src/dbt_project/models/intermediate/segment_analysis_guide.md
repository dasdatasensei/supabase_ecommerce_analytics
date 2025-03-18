# Olist E-commerce Segment Analysis Guide

## Customer Segments Analysis

### Business Use Cases

#### Frequency x Value Matrix

```sql
with customer_matrix as (
  select
    frequency_segment,
    value_segment,
    count(*) as customer_count,
    sum(total_spent) as total_revenue
  from {{ ref('int_customer_orders') }}
  group by 1, 2
)
select * from customer_matrix
order by frequency_segment, value_segment
```

**Business Applications:**

1. High-Value, High-Frequency

   - VIP loyalty program enrollment
   - Early access to new products
   - Exclusive customer service line
   - Personal shopping assistance

2. High-Value, Low-Frequency

   - Reactivation campaigns
   - Category expansion recommendations
   - Seasonal reminder campaigns
   - Premium product recommendations

3. Low-Value, High-Frequency
   - Cross-sell to higher value categories
   - Bundle deals promotion
   - Category discovery campaigns
   - Upgrade incentives

**Visualization Recommendations:**

- Heat map of customer concentration
- Bubble chart of revenue by segment
- Trend analysis of segment migration
- Stacked bar chart of segment distribution

### NPS Analysis

```sql
select
  nps_segment,
  count(*) as customer_count,
  avg(avg_review_score) as avg_satisfaction,
  sum(case when total_orders > 1 then 1 else 0 end)::float / count(*) as repeat_purchase_rate
from {{ ref('int_customer_orders') }}
group by 1
```

**Business Applications:**

1. Promoters

   - Referral program enrollment
   - Case study creation
   - Social proof campaigns
   - Brand ambassador selection

2. Detractors
   - Recovery campaigns
   - Feedback collection
   - Service improvement prioritization
   - Churn prevention initiatives

**Visualization Recommendations:**

- NPS distribution gauge chart
- Trend line of NPS over time
- Segment migration Sankey diagram
- Review score distribution by segment

## Seller Segments Analysis

### Performance Matrix

```sql
select
  performance_segment,
  delivery_segment,
  count(*) as seller_count,
  avg(total_gmv) as avg_gmv,
  avg(on_time_delivery_rate) as avg_delivery_rate
from {{ ref('int_seller_performance') }}
group by 1, 2
```

**Business Applications:**

1. Excellent Performance, Excellent Delivery

   - Featured seller status
   - Priority placement in search
   - Reduced commission rates
   - Advanced selling tools access

2. Poor Performance, Poor Delivery
   - Mandatory training programs
   - Performance improvement plans
   - Increased monitoring
   - Temporary search ranking reduction

**Visualization Recommendations:**

- Performance quadrant scatter plot
- Delivery rate distribution curve
- GMV by segment stacked area chart
- Year-over-year segment migration

### Volume and Value Analysis

```sql
with seller_growth as (
  select
    seller_id,
    volume_segment,
    value_segment,
    total_gmv,
    lag(total_gmv) over (partition by seller_id order by date_trunc('month', created_at)) as prev_month_gmv
  from {{ ref('int_seller_performance') }}
)
select
  volume_segment,
  value_segment,
  avg((total_gmv - prev_month_gmv) / nullif(prev_month_gmv, 0)) as avg_growth_rate
from seller_growth
group by 1, 2
```

**Business Applications:**

1. High Volume, High Value

   - Dedicated account management
   - Inventory financing options
   - Bulk shipping rates
   - Advanced analytics access

2. Growth Potential (Medium Volume/Value)
   - Growth acceleration programs
   - Marketing co-investment
   - Category expansion support
   - Business development workshops

**Visualization Recommendations:**

- Growth trajectory analysis
- Volume-value bubble chart
- Seller progression funnel
- Monthly GMV trend by segment

## Product Segments Analysis

### Category Performance

```sql
select
  pc.category_name,
  pp.volume_segment,
  pp.price_segment,
  count(*) as product_count,
  sum(total_gmv) as category_gmv,
  avg(avg_review_score) as avg_satisfaction
from {{ ref('int_product_performance') }} pp
join {{ ref('stg_olist__product_categories') }} pc
  on pp.category_id = pc.category_id
group by 1, 2, 3
```

**Business Applications:**

1. High Volume, Premium Price

   - Featured placement
   - Bundle creation
   - Cross-sell recommendations
   - Stock level optimization

2. Low Volume, High Rating
   - Visibility boost campaigns
   - Marketing feature spots
   - Category expansion
   - Seller collaboration programs

**Visualization Recommendations:**

- Category tree map by GMV
- Price-volume scatter plot
- Rating distribution by category
- Inventory turnover analysis

### Logistics Optimization

```sql
select
  weight_segment,
  size_segment,
  count(*) as product_count,
  avg(total_gmv) as avg_gmv,
  avg(avg_review_score) as avg_satisfaction
from {{ ref('int_product_performance') }}
group by 1, 2
```

**Business Applications:**

1. Heavy/Large Products

   - Special handling procedures
   - Warehouse space optimization
   - Bulk shipping negotiations
   - Regional inventory distribution

2. Light/Small Products
   - Batch processing optimization
   - Multi-item order promotion
   - Economic shipping options
   - Easy storage solutions

**Visualization Recommendations:**

- Size-weight matrix heat map
- Shipping cost analysis
- Storage utilization dashboard
- Delivery time comparison

## Monitoring and Reporting

### KPI Dashboard Recommendations

1. Customer Health

   - Segment distribution trends
   - Segment migration rates
   - Customer lifetime value by segment
   - Retention rates by segment

2. Seller Performance

   - GMV by segment
   - Delivery performance trends
   - Seller satisfaction scores
   - New seller progression

3. Product Analytics
   - Category performance
   - Price segment effectiveness
   - Inventory turnover by segment
   - Rating trends by segment

### Regular Review Process

1. Monthly Reviews

   - Segment distribution changes
   - New customer segment analysis
   - Seller performance updates
   - Product category trends

2. Quarterly Reviews

   - Segment threshold adjustments
   - Business impact analysis
   - Strategy effectiveness
   - Program ROI evaluation

3. Annual Planning
   - Segment strategy updates
   - Program redesign
   - Resource allocation
   - Growth target setting
