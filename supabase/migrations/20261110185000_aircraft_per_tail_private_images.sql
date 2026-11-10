-- Airlinerra per-aircraft photo upload. Each aircraft keeps its own private image.
-- No access to another airline's aircraft and no changes to fleet or finances.
BEGIN;
INSERT INTO storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
VALUES ('airlinerra-aircraft-images','airlinerra-aircraft-images',false,1048576,ARRAY['image/webp']::text[])
ON CONFLICT (id) DO UPDATE SET
 public=false,file_size_limit=1048576,allowed_mime_types=ARRAY['image/webp']::text[];

CREATE OR REPLACE FUNCTION public.airlinerra_own_aircraft_image_path_v1(object_name text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
 SELECT coalesce(
  auth.uid() IS NOT NULL
  AND object_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/aircraft[.]webp$'
  AND split_part(object_name,'/',1) = auth.uid()::text
  AND EXISTS (
   SELECT 1 FROM airlinerra_game.airlines a
   JOIN airlinerra_game.airline_aircraft_inventory i ON i.airline_id=a.id
   WHERE a.owner_player_id=auth.uid() AND a.world_id=1
     AND a.id::text=split_part(object_name,'/',2)
     AND i.id::text=split_part(object_name,'/',3)
  ),false);
$$;
REVOKE ALL ON FUNCTION public.airlinerra_own_aircraft_image_path_v1(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.airlinerra_own_aircraft_image_path_v1(text) TO authenticated;

DROP POLICY IF EXISTS airlinerra_aircraft_image_insert_own ON storage.objects;
CREATE POLICY airlinerra_aircraft_image_insert_own ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id='airlinerra-aircraft-images' AND public.airlinerra_own_aircraft_image_path_v1(name));
DROP POLICY IF EXISTS airlinerra_aircraft_image_read_own ON storage.objects;
CREATE POLICY airlinerra_aircraft_image_read_own ON storage.objects FOR SELECT TO authenticated
USING (bucket_id='airlinerra-aircraft-images' AND public.airlinerra_own_aircraft_image_path_v1(name));
DROP POLICY IF EXISTS airlinerra_aircraft_image_update_own ON storage.objects;
CREATE POLICY airlinerra_aircraft_image_update_own ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id='airlinerra-aircraft-images' AND public.airlinerra_own_aircraft_image_path_v1(name))
WITH CHECK (bucket_id='airlinerra-aircraft-images' AND public.airlinerra_own_aircraft_image_path_v1(name));
DROP POLICY IF EXISTS airlinerra_aircraft_image_delete_own ON storage.objects;
CREATE POLICY airlinerra_aircraft_image_delete_own ON storage.objects FOR DELETE TO authenticated
USING (bucket_id='airlinerra-aircraft-images' AND public.airlinerra_own_aircraft_image_path_v1(name));
COMMIT;
