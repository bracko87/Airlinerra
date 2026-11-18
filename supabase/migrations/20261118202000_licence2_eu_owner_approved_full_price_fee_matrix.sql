-- Owner-approved 2026-11-18: EU Licence 2 pricing.
-- Initial AND upgrade: full new-level price. Processing: 3 game days.
-- This is fee policy only. It must never enable issuance, take payment or activate flights.
begin;
do $$
declare v_bad integer;
begin
 select count(*) into v_bad
 from airlinerra_game.licence2_reviewed_fee_policy_v1 f
 where f.market_code='L2-EU' and
 not (
   (f.review_state='DRAFT' and f.fee_usd is null and f.processing_game_days is null)
   or (f.review_state='APPROVED' and f.processing_game_days=3
    and f.fee_usd=case f.level when 1 then 25000 when 2 then 75000
        when 3 then 200000 when 4 then 500000 end)
 );
 if v_bad>0 then raise exception 'LICENCE2_EU_FEE_POLICY_CONFLICT';end if;
 if (select count(*) from airlinerra_game.licence2_reviewed_fee_policy_v1
    where market_code='L2-EU')<>8
 then raise exception 'LICENCE2_EU_REQUIRES_ALL_8_PRICING_ROWS';end if;
end $$;
update airlinerra_game.licence2_reviewed_fee_policy_v1 f
set fee_usd=case level when 1 then 25000 when 2 then 75000
 when 3 then 200000 when 4 then 500000 end,
 processing_game_days=3,review_state='APPROVED',
 approved_by='Airlinerra game owner - direct pricing approval',
 approval_reference='Owner approved 2026-11-18: EU L2 1-4, 3 game days, upgrades at full new-level fee.',
 approved_at=now()
where market_code='L2-EU' and review_state='DRAFT';
do $$
begin
 if (select count(*) from airlinerra_game.licence2_reviewed_fee_policy_v1 f
  where market_code='L2-EU' and review_state='APPROVED'
  and processing_game_days=3
  and fee_usd=case f.level when 1 then 25000 when 2 then 75000
    when 3 then 200000 when 4 then 500000 end)<>8
 then raise exception 'LICENCE2_EU_FEE_MATRIX_NOT_VERIFIED';end if;
 if exists (select 1 from airlinerra_game.licence2_market_policy_v1
   where issuance_enabled or enforcement_enabled)
 or exists(select 1 from airlinerra_game.licence2_approval_release_v1
   where approval_enabled)
 then raise exception 'LICENCE2_FEE_POLICY_MUST_NOT_RELEASE_ISSUANCE';end if;
end $$;
commit;