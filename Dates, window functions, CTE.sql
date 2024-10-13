--function to decode cirillic letters
create or replace function pg_temp.decode_url_part(p varchar) 
returns varchar 
as 
$$
SELECT convert_from(CAST(E'\\x' || string_agg(
	CASE 
		WHEN length(r.m[1]) = 1 
		THEN encode(convert_to(r.m[1], 'SQL_ASCII'), 'hex') 
		ELSE substring(r.m[1] from 2 for 2) END, '') AS bytea), 'UTF8')
FROM regexp_matches($1, '%[0-9a-f][0-9a-f]|.', 'gi') AS r(m);
$$ 
LANGUAGE SQL 
IMMUTABLE STRICT; 

--joining Facebook_ and Google_ads_basic_daily with CTE
with CTE_facebook as (
select fabd.ad_date, 
fabd.url_parameters,
coalesce (fabd.spend, 0) as updated_spend,
coalesce (fabd.impressions, 0) as updated_impr,
coalesce (fabd.reach, 0) as updated_reach,
coalesce (fabd.clicks, 0) as updated_clicks,
coalesce (fabd.leads, 0) as updated_leads,
coalesce (fabd.value, 0) as updated_value
from facebook_ads_basic_daily fabd 
inner join facebook_campaign fc on fabd.campaign_id = fc.campaign_id
left join facebook_adset fa on fabd.adset_id = fa.adset_id
),
CTE_google as (
select *
from CTE_facebook
union
select gabd.ad_date,
gabd.url_parameters, 
coalesce (gabd.spend, 0) as updated_spend,
coalesce (gabd.impressions, 0) as updated_impr,
coalesce (gabd.reach, 0) as updated_reach,
coalesce (gabd.clicks, 0) as updated_clicks,
coalesce (gabd.leads, 0) as updated_leads,
coalesce (gabd.value, 0) as updated_value
from google_ads_basic_daily gabd
),
metrics_CTE as (
select 
date_trunc('month', g_cte.ad_date) as ad_month,
case 
	when lower(substring(g_cte.url_parameters, 'utm_campaign=([^\&]+)')) != 'nan'
	then pg_temp.decode_url_part(lower(substring(g_cte.url_parameters, 'utm_campaign=([^&#$]+)')))
end as utm_campaign, 
--total spend, impressions, clicks and value
sum(g_cte.updated_spend) as total_spend, 
sum(g_cte.updated_impr) as total_impr, 
sum(g_cte.updated_clicks) as total_clicks, 
sum(g_cte.updated_value) as total_value,
--CTR, CPM, ROMI  using case to avoid division by 0 error
case 
	when sum(g_cte.updated_impr) > 0 then
	round((sum(g_cte.updated_spend)/sum(g_cte.updated_impr)::numeric) *1000, 2) 
	else 0
end as cpm,
case 
	when sum(g_cte.updated_impr) > 0 then 
	round((sum(g_cte.updated_clicks)/sum(g_cte.updated_impr)::numeric)*100, 2) 
	else 0
end as ctr,
case   
	when sum(g_cte.updated_spend) > 0 then 
	round(((sum(g_cte.updated_value)-sum(g_cte.updated_spend))/sum(g_cte.updated_spend)::numeric) *100, 2) 
	else 0
end as romi
from CTE_google as g_cte
group by 1,2
),
compared_metrics as (
--using window function in this CTE to see CTR, CPM and ROMI for previous months
select*,
LAG(ctr) over (partition by m_cte.utm_campaign order by m_cte.ad_month) as prev_month_ctr,
LAG(cpm) over (partition by m_cte.utm_campaign order by m_cte.ad_month) as prev_month_cpm,
LAG(romi) over (partition by m_cte.utm_campaign order by m_cte.ad_month) as prev_month_romi
from metrics_cte as m_cte
)
--final select statement that represents all metrics needed and CTR, CPM and ROMI difference between current and previous month
select*,
case 
	when prev_month_ctr > 0 
	then round((ctr::numeric / prev_month_ctr - 1) * 100, 2)
	when prev_month_ctr = 0 and ctr > 0 
	then 100
end as ctr_diff,
case 
	when prev_month_cpm > 0 
	then round((cpm::numeric / prev_month_cpm - 1) * 100, 2)
	when prev_month_cpm = 0 and cpm > 0 
	then 100
end as cpm_diff,
case 
	when prev_month_romi > 0 
	then round((romi::numeric / prev_month_romi - 1) * 100, 2)
	when prev_month_romi = 0 and romi > 0 
	then 100
end as romi_diff
from compared_metrics as cm;






