--Создание справочника в shipping_country_rates
drop table if exists shipping_country_rates;
create table shipping_country_rates (
  id serial NOT NULL,
  shipping_country text NULL,
  shipping_country_base_rate numeric(14, 3) NULL,
  primary key (id)
);

insert into shipping_country_rates
(shipping_country, shipping_country_base_rate) 
select distinct shipping_country, shipping_country_base_rate from shipping;

--Создание справочника shipping_agreement
drop table if exists shipping_agreement;
create table shipping_agreement (
  agreement_id bigint NOT NULL,
  agreement_number varchar,
  agreement_rate numeric(14, 2),
  agreement_comission numeric(14, 2),
  primary key (agreement_id)
);

insert into shipping_agreement
(agreement_id, agreement_number, agreement_rate, agreement_comission)
  select distinct agreement[1]::bigint as agreement_id, 
    agreement[2]::varchar, 
	agreement[3]::numeric(14, 2), 
	agreement[4]::numeric(14, 2) 
	from
	  (select regexp_split_to_array(vendor_agreement_description, ':+') as agreement 
	            from shipping) as query_in
				order by agreement_id; 
				
--Создание справочника shipping_transfer 
drop table if exists shipping_transfer;
create table shipping_transfer (
  transfer_type_id serial NOT NULL,
  transfer_type varchar,
  transfer_model text,
  shipping_transfer_rate numeric(14, 3),
  primary key (transfer_type_id)
);

insert into shipping_transfer
(transfer_type, transfer_model, shipping_transfer_rate)
select description[1]::varchar, 
	   description[2], 
	   shipping_transfer_rate
	   from
	   	   (select regexp_split_to_array(shipping_transfer_description, ':+') as description, 
           shipping_transfer_rate
	       from shipping) as query_in
		   	   group by 1, 2, 3;

--Создание таблицы shipping_info 
drop table if exists shipping_info;
create table shipping_info (
  shippingid bigint NOT NULL,
  shipping_country_id bigint NOT NULL,
  agreement_id bigint NOT NULL,
  transfer_type_id bigint NOT NULL,
  shipping_plan_datetime timestamp,
  payment_amount numeric(14, 2), 
  vendorid bigint, 
  foreign key (shipping_country_id) references shipping_country_rates (id) on update cascade,
  foreign key (agreement_id) references shipping_agreement (agreement_id) on update cascade,
  foreign key (transfer_type_id) references shipping_transfer (transfer_type_id)  on update cascade
);


with cte as
(select id, regexp_split_to_array(vendor_agreement_description, ':+') as agreement 
	from shipping),
cte2 as
(select transfer_type_id, transfer_type || ':' || transfer_model  as trans_description 
 	from shipping_transfer)
insert into shipping_info
(shippingid, shipping_country_id, agreement_id, transfer_type_id, shipping_plan_datetime, payment_amount, vendorid) 
select distinct
	sh.shippingid,
	scr.id, 
	cte.agreement[1]::bigint,
	cte2.transfer_type_id,
 	sh.shipping_plan_datetime, 
 	sh.payment_amount, 
 	sh.vendorid
 	from shipping sh 
 		inner join shipping_country_rates scr on sh.shipping_country_base_rate = scr.shipping_country_base_rate
		inner join cte on cte.id = sh.id
		inner join cte2 on cte2.trans_description = sh.shipping_transfer_description;  

--Создание таблицы shipping_status
drop table if exists shipping_status;
create table shipping_status (
  shippingid bigint not null,
  status text,
  state text,
  shipping_start_fact_datetime timestamp,
  shipping_end_fact_datetime timestamp  
);

with max_time as  --Вычисление максимальных значений времени
	(select distinct shippingid, 
		max(state_datetime) over (partition by shippingid) as max_datetime
		from shipping),
start_time as    
	(select shippingid, state_datetime as start_fact --Вычисление времени start 
		from shipping
		where state = 'booked'),
end_time as    
	(select shippingid, state_datetime as end_fact --Вычисление времени end
		from shipping
		where state = 'recieved')
insert into shipping_status
(shippingid, status, state, shipping_start_fact_datetime, shipping_end_fact_datetime)
select mt.shippingid, status, state, start_fact, end_fact
  from max_time mt 
	inner join shipping sh on sh.shippingid = mt.shippingid
		and sh.state_datetime = mt.max_datetime
	left join start_time st on st.shippingid = mt.shippingid
	left join end_time et on et.shippingid = mt.shippingid;

--Создание витрины shipping_datamart
drop view if exists shipping_datamart;
create or replace view shipping_datamart as
select 
	  si.shippingid, 
	  vendorid, 
	  st.transfer_type_id, 
	  coalesce(nullif(date_trunc('days', (age(shipping_end_fact_datetime, shipping_start_fact_datetime)))::varchar, '00:00:00'), '<1 day')
		as full_day_at_shipping,
	  case when shipping_end_fact_datetime > shipping_plan_datetime
	    then 1 else 0 end
	    as is_delay,
	  case when status = 'finished'
	  	then 1 else 0 end 
		as is_shipping_finish,
	  case when shipping_end_fact_datetime > shipping_plan_datetime
	  	then date_trunc('days', (age(shipping_end_fact_datetime, shipping_plan_datetime)))::varchar else '0' end 
		as delay_day_at_shipping,
	  payment_amount, 
	  payment_amount * (shipping_country_base_rate + agreement_rate + shipping_transfer_rate) 
	  	as vat,
	  payment_amount * agreement_comission as profit
from shipping_status ss
	  inner join shipping_info si on ss.shippingid = si.shippingid
	  inner join shipping_country_rates scr on scr.id = si.shipping_country_id
	  inner join shipping_agreement sa on sa.agreement_id = si.agreement_id
	  inner join shipping_transfer st on si.transfer_type_id = st.transfer_type_id;