-- Licence 6 UI can offer the submission control only after all independently
-- verified policies and the separate live release switch actually pass.
DO $patch$
DECLARE fn text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO fn FROM pg_proc p
 JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='airlinerra_game' AND p.proname='licence6_fifth_readiness_v1';
 IF fn IS NULL OR strpos(fn,'''eligible'',cardinality(issues)=0,''canApply'',false')=0
 THEN RAISE EXCEPTION 'LICENCE6_EXPECTED_APPLY_ANCHOR_MISSING';END IF;
 EXECUTE replace(fn,
  '''eligible'',cardinality(issues)=0,''canApply'',false',
  '''eligible'',cardinality(issues)=0,''canApply'',cardinality(issues)=0');
END $patch$;