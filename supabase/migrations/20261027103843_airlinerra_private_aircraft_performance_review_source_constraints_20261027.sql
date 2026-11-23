
ALTER TABLE airlinerra.aircraft_performance_reference_sets
 DROP CONSTRAINT aircraft_performance_review_requires_reviewer;
ALTER TABLE airlinerra.aircraft_performance_reference_sets
 ADD CONSTRAINT aircraft_performance_review_requires_reviewer
 CHECK (
   review_status='UNVERIFIED'
   OR (
     reviewed_by IS NOT NULL
     AND length(trim(reviewed_by)) >= 2
     AND reviewed_on IS NOT NULL
   )
 );
ALTER TABLE airlinerra.aircraft_performance_reference_sets
 ADD CONSTRAINT aircraft_performance_reference_source_identity
 CHECK (
   length(trim(source_authority)) >= 3
   AND length(trim(source_document_ref)) >= 3
   AND length(trim(source_revision)) >= 1
 );
