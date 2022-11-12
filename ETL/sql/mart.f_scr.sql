delete from mart.f_customer_retention where period_id = date_part('week', ('{{ ds }}')::timestamp);

with cte as
	(select 
	 	date_part('week', date_time::timestamp) as period_id, 
	 	item_id, status, customer_id, 'weekly' as period_name, payment_amount,
		case when status = 'refunded' then payment_amount * -1 else payment_amount end as total_payment_amount,
	 	case when count(customer_id) = 1 and status = 'shipped' then count(customer_id) else 0 end as new_customers, 
	 	case when count(customer_id) > 1 and status = 'shipped' then count(customer_id) else NULL end as retention_customers,
	 	case when status = 'refunded' then count(distinct customer_id) else 0 end as refunded_customers,
		case when count(customer_id) = 1 and status = 'shipped' then count(customer_id) * payment_amount else 0 end as new_customers_revenue,
	 	case when count(customer_id) > 1 and status = 'shipped' then count(customer_id) * payment_amount else 0 end as retention_customers_revenue,
	 	case when status = 'refunded' then count(*) else 0 end as customers_refunded 
	from staging.user_order_log group by 1,2,3,4,5,6,7)
insert into mart.f_customer_retention (new_customers_count, returning_customers_count, refunded_customers_count, period_name, period_id, item_id, new_customers_revenue, returning_customers_revenue, customers_refunded)
select 
	   sum(new_customers) as new_customers_count,
	   count(retention_customers) as returning_customers_count,
	   sum(refunded_customers) as refunded_customers_count,
	   period_name, period_id, item_id,  
	   sum(new_customers_revenue) as new_customers_revenue,
	   sum(retention_customers_revenue) as returning_customers_revenue,
	   sum(customers_refunded) as customers_refunded
from cte
where cte.period_id = date_part('week', ('{{ ds }}')::timestamp)
group by 4, 5, 6
