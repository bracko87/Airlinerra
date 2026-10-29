-- Friendly names only. World identifiers, lifecycle states, game clocks,
-- memberships, airlines, approvals and release gates are untouched.
UPDATE public.airlinerra_game_worlds
SET name=CASE id
 WHEN 1 THEN 'Horizon'
 WHEN 2 THEN 'Atlas'
 WHEN 3 THEN 'Odyssey'
 ELSE name END
WHERE id IN (1,2,3)
  AND (id,name) IN (
   (1,'Founding World'),(1,'Horizon'),
   (2,'Expansion World'),(2,'Atlas'),
   (3,'Future World'),(3,'Odyssey')
  );
