-- A planned holding subsidiary is not a registered cargo airline.
-- Keep applications and issuance fail-closed until legal registration is confirmed.
DO $guard$
DECLARE f text; old_frag text:='AND s.company_kind=''cargo_airline''';
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO f
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='airlinerra_game' AND p.proname='licence3_cargo_readiness_v1';
 IF f IS NULL OR position(old_frag IN f)=0 THEN
  RAISE EXCEPTION 'LICENCE3_CARGO_READINESS_EXPECTED_PROVENANCE_NOT_FOUND';
 END IF;
 f:=replace(f,old_frag,old_frag||' AND s.formation_state=''registered''');
 EXECUTE f;
END $guard$;
