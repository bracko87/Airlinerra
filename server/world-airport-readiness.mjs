/**
 * Private read-only World 01–03 airport handoff audit.
 *
 * AIRPORT RESEARCH OWNERSHIP: This service never edits or approves airports,
 * populates approved_game_airports or exposes research data to browsers.
 * A research activation flag is NOT authority to admit an airport to gameplay.
 */
export const WORLD_AIRPORT_READINESS_SQL = [
  'select',
  'count(*)::integer as activated_records,',
  'count(*) filter (where r.airport_key is null)::integer as missing_registry,',
  'count(*) filter (where a.game_admission_status = \'APPROVED\'',
  'and a.owner_approved_at is not null',
  "and g.final_category in ('Local','Regional','Medium','Large','Major Hub','Mega Hub')",
  'and g.category_approved_at is not null)::integer as fully_review_approved,',
  "count(*) filter (where a.game_admission_status is distinct from 'APPROVED'",
  'or a.owner_approved_at is null',
  "or g.final_category not in ('Local','Regional','Medium','Large','Major Hub','Mega Hub')",
  'or g.final_category is null or g.category_approved_at is null)::integer as unresolved_approvals',
  'from airlinerra.airport_world_activation w',
  'left join airlinerra.airport_registry r on r.airport_key = w.airport_key',
  'left join airlinerra.airport_access_reviews a on a.airport_key = w.airport_key',
  'left join airlinerra.airport_game_profiles g on g.airport_key = w.airport_key',
  'where w.world_number = $1::smallint and w.active = true'
].join(' ');

export function createWorldAirportReadinessService({database,enabled=false}={}) {
  if (!database || typeof database.query !== 'function') {
    throw new Error('Read-only airport research query adapter required.');
  }
  return Object.freeze({
    async summarizeWorld(worldId) {
      if (!enabled) throw new Error('Airport handoff review is disabled.');
      if (!Number.isInteger(worldId) || worldId < 1 || worldId > 3) {
        throw new Error('Invalid game world.');
      }
      const response = await database.query(WORLD_AIRPORT_READINESS_SQL,[worldId]);
      const row = response?.rows?.[0];
      if (!row || response.rows.length !== 1) {
        throw new Error('Airport handoff verification failed.');
      }
      const fields = ['activated_records','missing_registry','fully_review_approved','unresolved_approvals'];
      if (fields.some(f => !Number.isSafeInteger(Number(row[f])) ||
          Number(row[f]) < 0 || row[f] === null)) {
        throw new Error('Airport handoff returned invalid counts.');
      }
      const activated = Number(row.activated_records);
      const missingRegistry = Number(row.missing_registry);
      const reviewApproved = Number(row.fully_review_approved);
      const unresolved = Number(row.unresolved_approvals);
      if (reviewApproved + unresolved !== activated || missingRegistry > activated) {
        throw new Error('Airport handoff counts are inconsistent.');
      }
      return Object.freeze({
        worldId,
        activated,
        reviewApproved,
        unresolved,
        missingRegistry,
        // Read-only diagnostics; never grants game approval or opens a world.
        approvalFullyReconciled: activated > 0 && missingRegistry === 0 && unresolved === 0
      });
    }
  });
}
