CREATE OR REPLACE FUNCTION airlinerra_game.section9_onboard_service_calculate_v1(p_key text, p_items jsonb, p_passengers integer, p_minutes numeric, p_reputation numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE c record; item jsonb; mode text; stock integer; price integer; duration_h numeric; length_factor numeric; price_factor numeric;
 rate numeric; loaded integer; sales integer; cost_units integer; row_cost bigint; row_income bigint; cost_total bigint:=0; income_total bigint:=0;
 free_weight integer:=0; paid_count integer:=0; rows jsonb:='[]'; unavailable jsonb:='[]'; satisfaction numeric;
BEGIN
 IF p_key IS NULL OR length(p_key) NOT BETWEEN 8 AND 180 OR jsonb_typeof(p_items) IS DISTINCT FROM 'object'
 OR p_passengers IS NULL OR p_passengers NOT BETWEEN 0 AND 1000 OR p_minutes IS NULL OR p_minutes NOT BETWEEN 15 AND 1440
 OR p_reputation IS NULL OR p_reputation NOT BETWEEN 0 AND 100 THEN RETURN jsonb_build_object('status','invalid_onboard_calculation');END IF;
 duration_h:=p_minutes/60;
 FOR c IN SELECT * FROM airlinerra_game.section9_onboard_service_catalog_v1 ORDER BY sort_order LOOP
  item:=coalesce(p_items->c.item_id,'{}'::jsonb);
  mode:=coalesce(item->>'mode','off'); stock:=0;price:=0;loaded:=0;sales:=0;cost_units:=0;rate:=0;
  IF mode NOT IN('off','included','onboard') THEN RETURN jsonb_build_object('status','invalid_onboard_service_mode','item',c.item_id);END IF;
  IF mode<>'off' AND NOT c.basic_delivery_supported THEN
   unavailable:=unavailable||jsonb_build_array(c.item_id);
   CONTINUE;
  END IF;
  IF mode='off' THEN CONTINUE;END IF;
  IF mode='included' THEN
   loaded:=CASE WHEN c.digital THEN 0 ELSE p_passengers END;
   cost_units:=p_passengers;IF p_passengers>0 THEN free_weight:=free_weight+c.included_weight;END IF;
  ELSE
   IF coalesce(item->>'onboardCents','') !~ '^[0-9]{1,6}$' OR coalesce(item->>'stockPer100','') !~ '^[0-9]{1,3}$' THEN RETURN jsonb_build_object('status','invalid_onboard_service_price_or_stock','item',c.item_id);END IF;
   price:=(item->>'onboardCents')::integer;stock:=(item->>'stockPer100')::integer;
   IF price NOT BETWEEN 0 AND 100000 OR stock NOT BETWEEN 0 AND 200 THEN RETURN jsonb_build_object('status','invalid_onboard_service_price_or_stock','item',c.item_id);END IF;
   length_factor:=CASE
    WHEN c.item_id='sandwich' THEN least(1.65,greatest(0.35,duration_h/2.6))
    WHEN c.item_id='snack' THEN least(1.55,greatest(0.45,duration_h/2.4))
    ELSE least(1.6,greatest(0.5,0.65+duration_h*0.13)) END;
   price_factor:=least(1.35,greatest(0.25,power(c.reference_price_cents::numeric/greatest(price,100),0.8::numeric)));
   rate:=least(0.65,c.base_purchase_rate*length_factor*(0.7+0.006*p_reputation)*price_factor);
   loaded:=CASE WHEN c.digital THEN 0 ELSE ceil(p_passengers*stock::numeric/100)::int END;
   -- Stable independent passenger/item draws, never clock-dependent.
   SELECT count(*)::int INTO sales FROM generate_series(1,p_passengers) j
    WHERE (('x'||substr(md5(p_key||':'||c.item_id||':'||j::text),1,8))::bit(32)::bigint)::numeric/4294967296 < rate;
   sales:=least(sales,CASE WHEN c.digital THEN p_passengers ELSE loaded END);
   cost_units:=CASE WHEN c.digital THEN sales ELSE loaded END;
   IF sales>0 THEN paid_count:=paid_count+1;END IF;
  END IF;
  row_cost:=cost_units::bigint*c.unit_cost_cents;row_income:=sales::bigint*price;
  cost_total:=cost_total+row_cost;income_total:=income_total+row_income;
  rows:=rows||jsonb_build_array(jsonb_build_object('itemId',c.item_id,'mode',mode,'loadedUnits',loaded,'includedUnits',CASE WHEN mode='included' THEN p_passengers ELSE 0 END,
   'paidSales',sales,'unsoldUnits',CASE WHEN mode='onboard' AND NOT c.digital THEN loaded-sales ELSE 0 END,
   'purchaseRate',round(rate,6),'unitCostCents',c.unit_cost_cents,'priceCents',price,'costCents',row_cost,'revenueCents',row_income));
 END LOOP;
 satisfaction:=CASE WHEN p_passengers=0 THEN 0 ELSE least(10,(free_weight+least(2,round(paid_count*0.5)))*0.2) END;
 RETURN jsonb_build_object('status','onboard_service_game_calculated','modelVersion','GAME_CABIN_SERVICE_V1','passengers',p_passengers,'durationMinutes',p_minutes,
 'reputationScore',p_reputation,'costCents',cost_total,'revenueCents',income_total,'netCents',income_total-cost_total,
 'satisfactionAdjustment',round(satisfaction,2),'unverifiedServicesExcluded',unavailable,'rows',rows,'ledgerPosted',false);
END;
$function$;