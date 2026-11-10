/** Airlinerra airport fuel-price preview, balance assumptions only.
 * No fuel contracts, no true airport price observations, no purchase/ledger.
 * Prices are modelled from the historical $0.95/kg game balance base and
 * World 1 airport tier. EIA independent spot reference is for comparisons,
 * NOT applied to game charges or represented as a supplier/airport quote.
 */
export const GAME_BASE_FUEL_USD_PER_KG=0.95;
export const PRICE_MODEL_VERSION='airport_tier_fuel_game_preview_v1';
export const BENCHMARK_SPOT=Object.freeze({
 name:'US Gulf Coast jet fuel spot',
 source:'U.S. Energy Information Administration (FRED DJFUELUSGULF)',
 url:'https://fred.stlouisfed.org/series/DJFUELUSGULF',
 observedDate:'2026-11-03',
 usdPerUsGallon:4.198,
 densityKgPerLiterAssumption:.8,
 usdPerKg:Math.round(4.198/(3.785411784*.8)*1000)/1000,
 applicability:'Regional wholesale spot indicator, NOT an airport delivery or contract quote'
});
export const AIRPORT_TIER_FACTORS=Object.freeze({
 'Mega Hub':.95,'Major Hub':.98,'Large':1.03,
 'Medium':1.07,'Regional':1.14,'Local':1.22
});
const moneyPrice=n=>Math.round(n*1000)/1000;
/** Airport profile is owner-authenticated and category either approved or provisional.
 * A profile without a known class never gets invented airport-specific pricing.
 */
export function previewAirportFuelPrice(airportProfile){
 const className=airportProfile?.category;
 const valid=Object.prototype.hasOwnProperty.call(AIRPORT_TIER_FACTORS,className);
 const factor=valid?AIRPORT_TIER_FACTORS[className]:1;
 const key=typeof airportProfile?.key==='string'?airportProfile.key:null;
 const sourceVerified=valid&&airportProfile?.categoryStatus==='approved';
 const usdPerKg=moneyPrice(GAME_BASE_FUEL_USD_PER_KG*factor);
 return Object.freeze({
  status:valid?'TIER_GAME_ESTIMATE':'GENERIC_GAME_BASE',
  modelVersion:PRICE_MODEL_VERSION,
  airportKey:key,
  gameCategory:valid?className:null,
  categoryApproved:sourceVerified,
  usdPerKg,
  factor,
  fuelType:'GENERIC_UNVERIFIED_JET_FUEL_BASIS',
  source:'GAME_BALANCING_ASSUMPTION',
  fromCurrentSupplier:false,
  currentAirportQuote:false,
  bookingEnabled:false,
  accountingEnabled:false,
  benchmarkSpot:BENCHMARK_SPOT,
  note:valid?'Tier multipliers are economic game estimates; actual airport prices differ.':
   'Airport category unknown; generic baseline only, not an airport-specific quote.'
 });
}
