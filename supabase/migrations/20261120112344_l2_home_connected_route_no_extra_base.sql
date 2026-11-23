-- A home-connected onward foreign segment does not require the airline to
-- establish a foreign hub merely for that leg. Licence 2 market scope remains
-- mandatory; actual continuous service, directed-route quota, slots and
-- international country rights MUST still be independently verified.
DO $patch$
DECLARE fn text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO fn FROM pg_proc p
 JOIN pg_namespace n ON p.pronamespace=n.oid
 WHERE n.nspname='airlinerra_game'
 AND p.proname='licence2_home_connected_foreign_segment_v1';
 IF fn IS NULL OR strpos(fn,
  'market_result->>''decision''=''L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK''')=0
 THEN RAISE EXCEPTION 'LICENCE2_HOME_CONNECTED_SEGMENT_NOT_FOUND';END IF;
 fn:=replace(fn,
 'market_result->>''decision''=''L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK''',
 'market_result->>''decision'' IN (''L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK'',''L2_ACTIVE_FOREIGN_HUB_NOT_VERIFIED'')');
 fn:=replace(fn,
 '''LICENCE2_ELIGIBLE_ROUTE_RIGHTS_REVIEW''',
 '''LICENCE2_MARKET_ELIGIBLE_COUNTRY_RIGHTS_REVIEW''');
 fn:=replace(fn,'''separateLicence6Required'',false',
 '''separateFifthFreedomLicenceRequired'',false');
 fn:=replace(fn,'''additionalLicence6FeeUsd'',0',
 '''additionalFifthFreedomLicenceFeeUsd'',0');
 fn:=replace(fn,
 '''requiresExistingDirectedRouteChecks'',true',
 '''requiresExistingDirectedRouteChecks'',true,''requiresSameHomeConnectedServiceProof'',true');
 EXECUTE fn;
END $patch$;