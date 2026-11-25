/**
 * Format-level policy for ordinary civil aircraft in Airlinerra, not a query
 * against real-world ownership or allocation databases. A format match never
 * establishes that the mark is free or legally allocated outside the game.
 * Deliberately not wired to live acquisitions until full registry-country
 * coverage and database-side enforcement are ready.
 */
const distress=['PAN','SOS','TTT','XXX'];
const rules=Object.freeze({
 RS:Object.freeze({prefix:'YU-',pattern:/^YU-[A-Z]{3}$/,example:'YU-ALX',
  source:'https://cad.gov.rs/strana/16551/zakoni-i-podzakonski-propisi?lang=en',
  authority:'Serbian CAD, Gazette 6/19, articles 3 and 5',
  additional:mark=>!mark.slice(3).startsWith('Q')&&!distress.includes(mark.slice(3))}),
 GB:Object.freeze({prefix:'G-',pattern:/^G-[A-Z]{4}$/,example:'G-ABCD',
  source:'https://www.caa.co.uk/aircraft-register/registration-marks/availability-of-uk-marks/',
  authority:'UK CAA, CAP 523 and UK marks allocation policy',
  additional:mark=>{const suffix=mark.slice(2);return !suffix.includes('Q')&&!suffix.includes('ZC')&&!distress.some(x=>suffix.includes(x));}}),
 US:Object.freeze({prefix:'N',pattern:/^N(?:[1-9][0-9]{0,4}|[1-9][0-9]{0,3}[A-HJ-NP-Z]|[1-9][0-9]{0,2}[A-HJ-NP-Z]{2})$/,example:'N123AB',
  source:'https://www.faa.gov/licenses_certificates/aircraft_certification/aircraft_registry/forming_nnumber',
  authority:'FAA, Forming an N-Number',
  additional:mark=>!/^N[1-9][0-9]?$/.test(mark)}),
 CA:Object.freeze({prefix:'C-',pattern:/^C-[FG][A-Z]{3}$/,example:'C-FABC',
  source:'https://tc.canada.ca/en/aviation/registering-leasing-aircraft/apply-manage-reservation-aircraft-registration-mark',
  authority:'Transport Canada, ordinary aircraft (not ultralights)',
  additional:()=>true})
});
export const VERIFIED_REGISTRY_COUNTRIES=Object.freeze(Object.keys(rules));
export function validateNationalAircraftRegistration(countryIso,registration){
 const country=typeof countryIso==='string'?countryIso.trim().toUpperCase():'';
 const mark=typeof registration==='string'?registration.trim().toUpperCase():'';
 const rule=Object.hasOwn(rules,country)?rules[country]:null;
 if(!rule)return Object.freeze({valid:false,status:'country_rule_not_verified',country});
 const valid=rule.pattern.test(mark)&&rule.additional(mark);
 return Object.freeze({valid,status:valid?'format_valid':'invalid_national_format',country,registration:mark,
  example:rule.example,authority:rule.authority,source:rule.source});
}
