-- Licence 5 must independently verify that the cargo subsidiary is registered.
DO $patch$
DECLARE fn text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO fn
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='airlinerra_game' AND p.proname='licence5_dg_readiness_v1';
 IF fn IS NULL OR strpos(fn,'AND s.company_kind=''cargo_airline''')=0
 THEN RAISE EXCEPTION 'LICENCE5_EXPECTED_COMPANY_PROVENANCE_NOT_FOUND';END IF;
 fn:=replace(fn,'AND s.company_kind=''cargo_airline''',
 'AND s.company_kind=''cargo_airline'' AND s.formation_state=''registered''');
 EXECUTE fn;
END $patch$;