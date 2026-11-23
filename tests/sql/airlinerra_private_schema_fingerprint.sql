-- READ ONLY. Deterministic structural hashes for Airlinerra's two private
-- schemas. Never exposes table rows or SQL bodies. Run on source and the
-- isolated schema-only clone BEFORE applying any forward corrections.
-- A hash match is a structural consistency signal, NOT an independent
-- security or data-integrity certification.
WITH objects AS (
  SELECT 'relation' AS kind,
    format('rel|%I.%I|%s|rls=%s|force=%s|acl=%s|view=%s',
      n.nspname,c.relname,c.relkind,c.relrowsecurity,c.relforcerowsecurity,
      coalesce(c.relacl::text,''),
      CASE WHEN c.relkind IN ('v','m') THEN coalesce(pg_get_viewdef(c.oid,true),'') ELSE '' END) AS ddl
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname IN ('airlinerra','airlinerra_game')
    AND c.relkind IN ('r','p','v','m','S','f')
  UNION ALL
  SELECT 'column',
    format('col|%I.%I.%I|%s|notnull=%s|identity=%s|generated=%s|default=%s',
      n.nspname,c.relname,a.attname,format_type(a.atttypid,a.atttypmod),
      a.attnotnull,a.attidentity,a.attgenerated,
      coalesce(pg_get_expr(d.adbin,d.adrelid),''))
  FROM pg_attribute a
  JOIN pg_class c ON c.oid=a.attrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
  WHERE n.nspname IN ('airlinerra','airlinerra_game')
    AND c.relkind IN ('r','p','v','m','f')
    AND a.attnum>0 AND NOT a.attisdropped
  UNION ALL
  SELECT 'constraint',
    format('con|%I.%I|%s|%s',n.nspname,c.relname,k.conname,
      pg_get_constraintdef(k.oid,true))
  FROM pg_constraint k
  JOIN pg_class c ON c.oid=k.conrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname IN ('airlinerra','airlinerra_game')
  UNION ALL
  SELECT 'index',
    format('idx|%I.%I|%s',n.nspname,c.relname,pg_get_indexdef(c.oid))
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname IN ('airlinerra','airlinerra_game') AND c.relkind='i'
  UNION ALL
  SELECT 'function',
    format('fn|%I.%I|%s|acl=%s',n.nspname,p.proname,
      pg_get_functiondef(p.oid),coalesce(p.proacl::text,''))
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname IN ('airlinerra','airlinerra_game')
  UNION ALL
  SELECT 'policy',
    format('pol|%I.%I|%s|%s|%s',n.nspname,c.relname,pol.polname,
      coalesce(pg_get_expr(pol.polqual,pol.polrelid),''),
      coalesce(pg_get_expr(pol.polwithcheck,pol.polrelid),''))
  FROM pg_policy pol
  JOIN pg_class c ON c.oid=pol.polrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname IN ('airlinerra','airlinerra_game')
  UNION ALL
  SELECT 'trigger',
    format('trg|%I.%I|%s',n.nspname,c.relname,pg_get_triggerdef(t.oid,true))
  FROM pg_trigger t
  JOIN pg_class c ON c.oid=t.tgrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname IN ('airlinerra','airlinerra_game') AND NOT t.tgisinternal
)
SELECT kind,count(*)::integer AS item_count,
  encode(extensions.digest(string_agg(ddl,E'\n' ORDER BY ddl),'sha256'),'hex') AS signature_sha256
FROM objects
GROUP BY kind ORDER BY kind;
