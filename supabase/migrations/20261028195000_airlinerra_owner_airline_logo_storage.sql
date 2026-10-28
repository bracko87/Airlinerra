-- Private owner logo storage. Uploaded only after a verified backend airline activation.
-- The bucket is not public and limits all uploads to a 1 MB WebP image.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES ('airlinerra-airline-logos','airlinerra-airline-logos',false,1048576,ARRAY['image/webp'])
ON CONFLICT (id) DO NOTHING;
CREATE POLICY "airlinerra_logo_read_own" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id='airlinerra-airline-logos' AND (storage.foldername(name))[1]=(select auth.uid()::text));
CREATE POLICY "airlinerra_logo_insert_own" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id='airlinerra-airline-logos' AND (storage.foldername(name))[1]=(select auth.uid()::text)
AND name ~ '^[a-f0-9-]{36}/[a-f0-9-]{36}/logo\\.webp$');
CREATE POLICY "airlinerra_logo_update_own" ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id='airlinerra-airline-logos' AND (storage.foldername(name))[1]=(select auth.uid()::text))
WITH CHECK (bucket_id='airlinerra-airline-logos' AND (storage.foldername(name))[1]=(select auth.uid()::text)
AND name ~ '^[a-f0-9-]{36}/[a-f0-9-]{36}/logo\\.webp$');
