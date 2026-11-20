-- Licence 2 permits use status 'approved', not 'active'.
-- Correct Fifth Freedom dependency before any permission could be released.
DO $patch$
DECLARE fn text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO fn
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='airlinerra_game' AND p.proname='licence6_fifth_readiness_v1';
 IF fn IS NULL OR strpos(fn,'l2.status=''active''')=0
 THEN RAISE EXCEPTION 'LICENCE6_MARKET_PERMIT_PREDICATE_MISSING';END IF;
 EXECUTE replace(fn,'l2.status=''active''','l2.status=''approved''');
END $patch$;